

open class XCTestExpectation {
    private static var currentMonotonicallyIncreasingToken: UInt64 = 0
    private static func queue_nextMonotonicallyIncreasingToken() -> UInt64 {
        dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
        currentMonotonicallyIncreasingToken += 1
        return currentMonotonicallyIncreasingToken
    }
    private static func nextMonotonicallyIncreasingToken() -> UInt64 {
        return XCTWaiter.subsystemQueue.sync { queue_nextMonotonicallyIncreasingToken() }
    }
    
    /*
     Rules for properties
     ====================
     
     XCTestExpectation has many properties, many of which require synchronization on `XCTWaiter.subsystemQueue`.
     When adding properties, use the following rules for consistency. The naming guidelines aim to allow
     property names to be as short & simple as possible, while maintaining the necessary synchronization.
     
     - If property is constant (`let`), it is immutable so there is no synchronization concern.
     - No underscore prefix on name
     - No matching `queue_` property
     - If it is only used within this file:
     - `private` access
     - If is is used outside this file but not outside the module:
     - `internal` access
     - If it is used outside the module:
     - `public` or `open` access, depending on desired overridability
     
     - If property is variable (`var`), it is mutable so access to it must be synchronized.
     - `private` access
     - If it is only used within this file:
     - No underscore prefix on name
     - No matching `queue_` property
     - If is is used outside this file:
     - If access outside this file is always on-queue:
     - No underscore prefix on name
     - Matching internal `queue_` property with `.onQueue` dispatchPreconditions
     - If access outside this file is sometimes off-queue
     - Underscore prefix on name
     - Matching `internal` property with `queue_` prefix and `XCTWaiter.subsystemQueue` dispatchPreconditions
     - Matching `internal` or `public` property without underscore prefix but with `XCTWaiter.subsystemQueue` synchronization
     */
    
    private var _expectationDescription: String
    
    internal let creationToken: UInt64
    internal let creationSourceLocation: SourceLocation
    
    private var isFulfilled = false
    private var fulfillmentToken: UInt64 = 0
    private var _fulfillmentSourceLocation: SourceLocation?
    
    private var _expectedFulfillmentCount = 1
    private var numberOfFulfillments = 0
    
    private var _isInverted = false
    
    private var _assertForOverFulfill = false
    
    private var _hasBeenWaitedOn = false
    
    private var _didFulfillHandler: (() -> Void)?
    
    /// A human-readable string used to describe the expectation in log output and test reports.
    open var expectationDescription: String {
        get {
            return XCTWaiter.subsystemQueue.sync { queue_expectationDescription }
        }
        set {
            XCTWaiter.subsystemQueue.sync { queue_expectationDescription = newValue }
        }
    }
    
    // 所以, 这其实是一个计算属性, 真正的值是 queue_expectedFulfillmentCount
    // 这个计算属性的作用就是, 在 XCTWaiter.subsystemQueue 里面, 进行 get, set 操作.
    open var expectedFulfillmentCount: Int {
        get {
            return XCTWaiter.subsystemQueue.sync { queue_expectedFulfillmentCount }
        }
        set {
            XCTWaiter.subsystemQueue.sync {
                precondition(!queue_hasBeenWaitedOn, "API violation - cannot set expectedFulfillmentCount on '\(queue_expectationDescription)' after already waiting on it.")
                queue_expectedFulfillmentCount = newValue
            }
        }
    }
    
    /// If an expectation is set to be inverted, then fulfilling it will have a similar effect as
    /// failing to fulfill a conventional expectation has, as handled by the waiter and its delegate.
    /// Furthermore, waiters that wait on an inverted expectation will allow the full timeout to elapse
    /// and not report timeout to the delegate if it is not fulfilled.
    open var isInverted: Bool {
        get {
            return XCTWaiter.subsystemQueue.sync { queue_isInverted }
        }
        set {
            XCTWaiter.subsystemQueue.sync {
                precondition(!queue_hasBeenWaitedOn, "API violation - cannot set isInverted on '\(queue_expectationDescription)' after already waiting on it.")
                queue_isInverted = newValue
            }
        }
    }
    
    // assertForOverFulfill 是一个计算属性, get, set 里面, 都是为了提供 XCTWaiter.subsystemQueue.sync 操作.
    open var assertForOverFulfill: Bool {
        get {
            return XCTWaiter.subsystemQueue.sync { _assertForOverFulfill }
        }
        set {
            XCTWaiter.subsystemQueue.sync {
                precondition(!queue_hasBeenWaitedOn, "API violation - cannot set assertForOverFulfill on '\(queue_expectationDescription)' after already waiting on it.")
                _assertForOverFulfill = newValue
            }
        }
    }
    
    internal var fulfillmentSourceLocation: SourceLocation? {
        return XCTWaiter.subsystemQueue.sync { _fulfillmentSourceLocation }
    }
    
    internal var hasBeenWaitedOn: Bool {
        return XCTWaiter.subsystemQueue.sync { queue_hasBeenWaitedOn }
    }
    
    internal var queue_expectationDescription: String {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return _expectationDescription
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            _expectationDescription = newValue
        }
    }
    internal var queue_isFulfilled: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return isFulfilled
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            isFulfilled = newValue
        }
    }
    internal var queue_fulfillmentToken: UInt64 {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return fulfillmentToken
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            fulfillmentToken = newValue
        }
    }
    internal var queue_expectedFulfillmentCount: Int {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return _expectedFulfillmentCount
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            _expectedFulfillmentCount = newValue
        }
    }
    internal var queue_isInverted: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return _isInverted
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            _isInverted = newValue
        }
    }
    internal var queue_hasBeenWaitedOn: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return _hasBeenWaitedOn
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            _hasBeenWaitedOn = newValue
            
            if _hasBeenWaitedOn {
                didBeginWaiting()
            }
        }
    }
    internal var queue_didFulfillHandler: (() -> Void)? {
        get {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            return _didFulfillHandler
        }
        set {
            dispatchPrecondition(condition: .onQueue(XCTWaiter.subsystemQueue))
            _didFulfillHandler = newValue
        }
    }
    
    public init(description: String = "no description provided", file: StaticString = #file, line: Int = #line) {
        _expectationDescription = description
        creationToken = XCTestExpectation.nextMonotonicallyIncreasingToken()
        creationSourceLocation = SourceLocation(file: file, line: line)
    }
    
    // 这里, expection 的 fulfill 怎么影响到 waiter 里面的 runloop 的.
    open func fulfill(_ file: StaticString = #file, line: Int = #line) {
        
        let sourceLocation = SourceLocation(file: file, line: line)
        // 不是很明白, 这种提前定义后面调用到底有什么意义. 直接调用不得了.
        // 如果, 后面还需要重用, 这么做还有一点意义, 但是后面就是直接调用了.
        // 为了让变量名, 展示这段代码的含义???
        let didFulfillHandler: (() -> Void)? = XCTWaiter.subsystemQueue.sync {
            if queue_isFulfilled, _assertForOverFulfill, let testCase = XCTCurrentTestCase {
                testCase.recordFailure(
                    description: "API violation - multiple calls made to XCTestExpectation.fulfill() for \(queue_expectationDescription).",
                    at: sourceLocation,
                    expected: false)
                return nil
            }
            
            if queue_fulfill(sourceLocation: sourceLocation) {
                return queue_didFulfillHandler
            } else {
                return nil
            }
        }
        
        didFulfillHandler?()
    }
    
    private func queue_fulfill(sourceLocation: SourceLocation) -> Bool {
        numberOfFulfillments += 1
        // 如果, 当前已经实现的数量, 大于了 queue_expectedFulfillmentCount, 才能算是满足条件了.
        if numberOfFulfillments == queue_expectedFulfillmentCount {
            queue_isFulfilled = true
            _fulfillmentSourceLocation = sourceLocation
            queue_fulfillmentToken = XCTestExpectation.queue_nextMonotonicallyIncreasingToken()
            return true
        } else {
            return false
        }
    }
    
    internal func didBeginWaiting() {
    }
    
    internal func cleanUp() {
    }
    
}

extension XCTestExpectation: Equatable {
    public static func == (lhs: XCTestExpectation, rhs: XCTestExpectation) -> Bool {
        return lhs === rhs
    }
}

extension XCTestExpectation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension XCTestExpectation: CustomStringConvertible {
    public var description: String {
        return expectationDescription
    }
}
