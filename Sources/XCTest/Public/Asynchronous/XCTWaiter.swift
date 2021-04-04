/// Events are reported to the waiter's delegate via these methods. XCTestCase conforms to this
/// protocol and will automatically report timeouts and other unexpected events as test failures.
///
/// - Note: These methods are invoked on an arbitrary queue.
public protocol XCTWaiterDelegate: AnyObject {
    
    /// Invoked when not all waited on expectations are fulfilled during the timeout period. If the delegate
    /// is an XCTestCase instance, this will be reported as a test failure.
    ///
    /// - Parameter waiter: The waiter which timed out.
    /// - Parameter unfulfilledExpectations: The expectations which were unfulfilled when `waiter` timed out.
    func waiter(_ waiter: XCTWaiter, didTimeoutWithUnfulfilledExpectations unfulfilledExpectations: [XCTestExpectation])
    
    /// Invoked when the wait specified that fulfillment order should be enforced and an expectation
    /// has been fulfilled in the wrong order. If the delegate is an XCTestCase instance, this will be reported
    /// as a test failure.
    ///
    /// - Parameter waiter: The waiter which had an ordering violation.
    /// - Parameter expectation: The expectation which was fulfilled instead of the required expectation.
    /// - Parameter requiredExpectation: The expectation which was fulfilled instead of the required expectation.
    func waiter(_ waiter: XCTWaiter, fulfillmentDidViolateOrderingConstraintsFor expectation: XCTestExpectation, requiredExpectation: XCTestExpectation)
    
    /// Invoked when an expectation marked as inverted is fulfilled. If the delegate is an XCTestCase instance,
    /// this will be reported as a test failure.
    ///
    /// - Parameter waiter: The waiter which had an inverted expectation fulfilled.
    /// - Parameter expectation: The inverted expectation which was fulfilled.
    ///
    /// - SeeAlso: `XCTestExpectation.isInverted`
    func waiter(_ waiter: XCTWaiter, didFulfillInvertedExpectation expectation: XCTestExpectation)
    
    /// Invoked when the waiter is interrupted prior to its expectations being fulfilled or timing out.
    /// This occurs when an "outer" waiter times out, resulting in any waiters nested inside it being
    /// interrupted to allow the call stack to quickly unwind.
    ///
    /// - Parameter waiter: The waiter which was interrupted.
    /// - Parameter outerWaiter: The "outer" waiter which interrupted `waiter`.
    func nestedWaiter(_ waiter: XCTWaiter, wasInterruptedByTimedOutWaiter outerWaiter: XCTWaiter)
    
}

// All `XCTWaiterDelegate` methods are optional, so empty default implementations are provided
public extension XCTWaiterDelegate {
    func waiter(_ waiter: XCTWaiter, didTimeoutWithUnfulfilledExpectations unfulfilledExpectations: [XCTestExpectation]) {}
    func waiter(_ waiter: XCTWaiter, fulfillmentDidViolateOrderingConstraintsFor expectation: XCTestExpectation, requiredExpectation: XCTestExpectation) {}
    func waiter(_ waiter: XCTWaiter, didFulfillInvertedExpectation expectation: XCTestExpectation) {}
    func nestedWaiter(_ waiter: XCTWaiter, wasInterruptedByTimedOutWaiter outerWaiter: XCTWaiter) {}
}

/// Manages waiting - pausing the current execution context - for an array of XCTestExpectations. Waiters
/// can be used with or without a delegate to respond to events such as completion, timeout, or invalid
/// expectation fulfillment. XCTestCase conforms to the delegate protocol and will automatically report
/// timeouts and other unexpected events as test failures.
///
/// Waiters can be used without a delegate or any association with a test case instance. This allows test
/// support libraries to provide convenience methods for waiting without having to pass test cases through
/// those APIs.
open class XCTWaiter {
    
    /// Values returned by a waiter when it completes, times out, or is interrupted due to another waiter
    /// higher in the call stack timing out.
    public enum Result: Int {
        case completed = 1
        case timedOut
        case incorrectOrder
        case invertedFulfillment
        case interrupted
    }
    
    // 这里, 使用 enum, 让数据的组织方式, 变得更加的清晰. 具有状态管理的共用体.
    private enum State: Equatable {
        case ready
        case waiting(state: Waiting)
        case finished(state: Finished)
        
        struct Waiting: Equatable {
            var enforceOrder: Bool
            var expectations: [XCTestExpectation]
            var fulfilledExpectations: [XCTestExpectation]
        }
        
        struct Finished: Equatable {
            let result: Result
            let fulfilledExpectations: [XCTestExpectation]
            let unfulfilledExpectations: [XCTestExpectation]
        }
        
        var allExpectations: [XCTestExpectation] {
            switch self {
            case .ready:
                return []
            case let .waiting(waitingState):
                return waitingState.expectations
            case let .finished(finishedState):
                return finishedState.fulfilledExpectations + finishedState.unfulfilledExpectations
            }
        }
    }
    
    internal static let subsystemQueue = DispatchQueue(label: "org.swift.XCTest.XCTWaiter")
    
    private var state = State.ready
    internal var timeout: TimeInterval = 0
    internal var waitSourceLocation: SourceLocation?
    private weak var manager: WaiterManager<XCTWaiter>?
    private var runLoop: RunLoop?
    
    private weak var _delegate: XCTWaiterDelegate?
    private let delegateQueue = DispatchQueue(label: "org.swift.XCTest.XCTWaiter.delegate")
    
    /// The waiter delegate will be called with various events described in the `XCTWaiterDelegate` protocol documentation.
    ///
    /// - SeeAlso: `XCTWaiterDelegate`
    open var delegate: XCTWaiterDelegate? {
        get {
            return XCTWaiter.subsystemQueue.sync { _delegate }
        }
        set {
            dispatchPrecondition(condition: .notOnQueue(XCTWaiter.subsystemQueue))
            XCTWaiter.subsystemQueue.async { self._delegate = newValue }
        }
    }
    
    /// Returns an array containing the expectations that were fulfilled, in that order, up until the waiter
    /// stopped waiting. Expectations fulfilled after the waiter stopped waiting will not be in the array.
    /// The array will be empty until the waiter has started waiting, even if expectations have already been
    /// fulfilled.
    open var fulfilledExpectations: [XCTestExpectation] {
        return XCTWaiter.subsystemQueue.sync {
            let fulfilledExpectations: [XCTestExpectation]
            
            switch state {
            case .ready:
                fulfilledExpectations = []
            case let .waiting(waitingState):
                fulfilledExpectations = waitingState.fulfilledExpectations
            case let .finished(finishedState):
                fulfilledExpectations = finishedState.fulfilledExpectations
            }
            
            // Sort by fulfillment token before returning, since it is the true fulfillment order.
            // The waiter being notified by the expectation isn't guaranteed to happen in the same order.
            return fulfilledExpectations.sorted { $0.queue_fulfillmentToken < $1.queue_fulfillmentToken }
        }
    }
    
    /// Initializes a waiter with an optional delegate.
    public init(delegate: XCTWaiterDelegate? = nil) {
        _delegate = delegate
    }
    
    
    /*
     Wait 的主要思路
     
     首先, 将自己处于 State.Waiting 的状态. 在这个过程里面, 会配置每个 expection 的 fulfill 回调, 就是到 waiter 里面来判断, 是不是所有的 expection 都达到了完成状态. 最终, 会影响要 isFinish 的状态.
     然后, 调用 runLoop 的 run 方法, 卡住当前的 codeFlow. 在 while 循环里面, 根据 isFinish, 和 timeout 来决定, 是否一值让 runloop 继续运行.
     跳出 runloop 之后, 检查所有的 expections 的状态, 和退出 runloop 的原因. 如果没有达到完成的状态, 那么通知 testCase 记录, 没有达到 success 的结果.
     
     所以, 异步测试, 还是要等. 
     */
    @discardableResult
    open func wait(for expectations: [XCTestExpectation], timeout: TimeInterval, enforceOrder: Bool = false, file: StaticString = #file, line: Int = #line) -> Result {
        
        // 首先, 判断一下 expectations 里面不能有重复的数据. 这里之所以不用 set, 是因为 API 设计的时候, 有着 order 的考虑.
        precondition(Set(expectations).count == expectations.count, "API violation - each expectation can appear only once in the 'expectations' parameter.")
        
        // 这里, 因为同名, 所以使用了 self.
        self.timeout = timeout
        waitSourceLocation = SourceLocation(file: file, line: line)
        
        // 初始化了状态, 为 waiting 状态.
        let runLoop = RunLoop.current
        XCTWaiter.subsystemQueue.sync {
            let waitingState = State.Waiting(
                enforceOrder: enforceOrder,
                expectations: expectations,
                fulfilledExpectations: expectations.filter { $0.queue_isFulfilled }
            )
            queue_configureExpectations(expectations)
            state = .waiting(state: waitingState)
            self.runLoop = runLoop
            queue_validateExpectationFulfillment(dueToTimeout: false)
        }
        
        let manager = WaiterManager<XCTWaiter>.current
        manager.startManaging(self, timeout: timeout)
        self.manager = manager
        
        // 使用 runloop 来阻止 code flow.
        let timeoutTimestamp = Date.timeIntervalSinceReferenceDate + timeout
        while !isFinished {
            let remaining = timeoutTimestamp - Date.timeIntervalSinceReferenceDate
            if remaining <= 0 {
                break
            }
            primitiveWait(using: runLoop, duration: remaining)
        }
        
        manager.stopManaging(self)
        self.manager = nil
        
        let result: Result = XCTWaiter.subsystemQueue.sync {
            queue_validateExpectationFulfillment(dueToTimeout: true)
            
            for expectation in expectations {
                expectation.cleanUp()
                expectation.queue_didFulfillHandler = nil
            }
            
            guard case let .finished(finishedState) = state else { fatalError("Unexpected state: \(state)") }
            return finishedState.result
        }
        
        return result
    }
    
    /// Convenience API to create an XCTWaiter which then waits on an array of expectations for up to the specified timeout, and optionally specify whether they
    /// must be fulfilled in the given order. May return early based on fulfillment of the waited on expectations. The waiter
    /// is discarded when the wait completes.
    ///
    /// - Parameter expectations: The expectations to wait on.
    /// - Parameter timeout: The maximum total time duration to wait on all expectations.
    /// - Parameter enforceOrder: Specifies whether the expectations must be fulfilled in the order
    ///   they are specified in the `expectations` Array. Default is false.
    /// - Parameter file: The file name to use in the error message if
    ///   expectations are not fulfilled before the given timeout. Default is the file
    ///   containing the call to this method. It is rare to provide this
    ///   parameter when calling this method.
    /// - Parameter line: The line number to use in the error message if the
    ///   expectations are not fulfilled before the given timeout. Default is the line
    ///   number of the call to this method in the calling file. It is rare to
    ///   provide this parameter when calling this method.
    open class func wait(for expectations: [XCTestExpectation], timeout: TimeInterval, enforceOrder: Bool = false, file: StaticString = #file, line: Int = #line) -> Result {
        return XCTWaiter().wait(for: expectations, timeout: timeout, enforceOrder: enforceOrder, file: file, line: line)
    }
    
    deinit {
        for expectation in state.allExpectations {
            expectation.cleanUp()
        }
    }
    
    private func queue_configureExpectations(_ expectations: [XCTestExpectation]) {
        dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
        
        for expectation in expectations {
            //  expectation 的 fulFill 的回调在这里设置的.
            expectation.queue_didFulfillHandler = { [weak self, unowned expectation] in
                self?.expectationWasFulfilled(expectation)
            }
            expectation.queue_hasBeenWaitedOn = true
        }
    }
    
    private func queue_validateExpectationFulfillment(dueToTimeout: Bool) {
        
        
        guard case let .waiting(waitingState) = state else { return }
        
        // 在这里, 抽取出所有已经完成的 expection, 
        let validatableExpectations = waitingState.expectations.map { ValidatableXCTestExpectation(expectation: $0) }
        let validationResult = XCTWaiter.validateExpectations(validatableExpectations,
                                                              dueToTimeout: dueToTimeout,
                                                              enforceOrder: waitingState.enforceOrder)
        
        switch validationResult {
        case .complete:
            queue_finish(result: .completed, cancelPrimitiveWait: !dueToTimeout)
            
        case .fulfilledInvertedExpectation(let invertedValidationExpectation):
            queue_finish(result: .invertedFulfillment, cancelPrimitiveWait: true) { delegate in
                delegate.waiter(self, didFulfillInvertedExpectation: invertedValidationExpectation.expectation)
            }
            
        case .violatedOrderingConstraints(let validationExpectation, let requiredValidationExpectation):
            queue_finish(result: .incorrectOrder, cancelPrimitiveWait: true) { delegate in
                delegate.waiter(self, fulfillmentDidViolateOrderingConstraintsFor: validationExpectation.expectation, requiredExpectation: requiredValidationExpectation.expectation)
            }
            
        case .timedOut(let unfulfilledValidationExpectations):
            queue_finish(result: .timedOut, cancelPrimitiveWait: false) { delegate in
                delegate.waiter(self, didTimeoutWithUnfulfilledExpectations: unfulfilledValidationExpectations.map { $0.expectation })
            }
            
        case .incomplete:
            break
            
        }
    }
    
    private func queue_finish(result: Result, cancelPrimitiveWait: Bool, delegateBlock: ((XCTWaiterDelegate) -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
        guard case let .waiting(waitingState) = state else { preconditionFailure("Unexpected state: \(state)") }
        
        let unfulfilledExpectations = waitingState.expectations.filter { !waitingState.fulfilledExpectations.contains($0) }
        
        state = .finished(state: State.Finished(
            result: result,
            fulfilledExpectations: waitingState.fulfilledExpectations,
            unfulfilledExpectations: unfulfilledExpectations
        ))
        
        if cancelPrimitiveWait {
            self.cancelPrimitiveWait()
        }
        
        if let delegateBlock = delegateBlock, let delegate = _delegate {
            delegateQueue.async {
                delegateBlock(delegate)
            }
        }
    }
    
    private func expectationWasFulfilled(_ expectation: XCTestExpectation) {
        XCTWaiter.subsystemQueue.sync {
            // If already finished, do nothing
            guard case var .waiting(waitingState) = state else { return }
            
            waitingState.fulfilledExpectations.append(expectation)
            queue_validateExpectationFulfillment(dueToTimeout: false)
        }
    }
    
}

private extension XCTWaiter {
    // 不断的调用 runLoop
    func primitiveWait(using runLoop: RunLoop, duration timeout: TimeInterval) {
        let timeIntervalToRun = min(0.1, timeout)
        _ = runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: timeIntervalToRun))
    }
    
    func cancelPrimitiveWait() {
        guard let runLoop = runLoop else { return }
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        CFRunLoopStop(runLoop.getCFRunLoop())
        #else
        runLoop._stop()
        #endif
    }
}

extension XCTWaiter: Equatable {
    public static func == (lhs: XCTWaiter, rhs: XCTWaiter) -> Bool {
        return lhs === rhs
    }
}

extension XCTWaiter: CustomStringConvertible {
    public var description: String {
        return XCTWaiter.subsystemQueue.sync {
            let expectationsString = state.allExpectations.map { "'\($0.queue_expectationDescription)'" }.joined(separator: ", ")
            
            return "<XCTWaiter expectations: \(expectationsString)>"
        }
    }
}

extension XCTWaiter: ManageableWaiter {
    
    var isFinished: Bool {
        return XCTWaiter.subsystemQueue.sync {
            switch state {
            case .ready, .waiting: return false
            case .finished: return true
            }
        }
    }
    
    func queue_handleWatchdogTimeout() {
        dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
        
        queue_validateExpectationFulfillment(dueToTimeout: true)
        manager!.queue_handleWatchdogTimeout(of: self)
        cancelPrimitiveWait()
    }
    
    func queue_interrupt(for interruptingWaiter: XCTWaiter) {
        dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
        
        queue_finish(result: .interrupted, cancelPrimitiveWait: true) { delegate in
            delegate.nestedWaiter(self, wasInterruptedByTimedOutWaiter: interruptingWaiter)
        }
    }
}
