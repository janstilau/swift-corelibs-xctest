// 这个闭包, 就是 Invocation 的作用.
// Invocation 是设置一个 target, 然后调用 invoke 方法. invoke 方法会调用对应的 selector.
// 这个闭包, 是传入一个 instance, 在闭包内部逻辑, 封装了对于各个成员函数的调用.
// 具体的生成过程, 应该在
// public func testCase<T: XCTestCase>(_ allTests: [(String, (T) -> () throws -> Void)]) -> XCTestCaseEntry
// 中.
public typealias XCTestCaseClosure = (XCTestCase) throws -> Void

// 一个类所代表的所有测试方法模型. 挂钩了要测试类的类型, 各个测试方法, 以及对于各个测试方法调用的闭包.
public typealias XCTestCaseEntry = (testCaseClass: XCTestCase.Type,
                                    allTests: [(String, XCTestCaseClosure)])

// A global pointer to the currently running test case. This is required in
// order for XCTAssert functions to report failures.
internal var XCTCurrentTestCase: XCTestCase?

/// An instance of this class represents an individual test case which can be
/// run by the framework. This class is normally subclassed and extended with
/// methods containing the tests to run.
/// - seealso: `XCTMain`
open class XCTestCase: XCTest {
    private let testClosure: XCTestCaseClosure
    
    private var skip: XCTSkip?
    
    /// The name of the test case, consisting of its class name and the method
    /// name it will run.
    open override var name: String {
        return _name
    }
    private var _name: String
    
    open override var testCaseCount: Int {
        return 1
    }
    
    internal var currentWaiter: XCTWaiter?
    
    /// The set of expectations made upon this test case.
    private var _allExpectations = [XCTestExpectation]()
    
    internal var expectations: [XCTestExpectation] {
        return XCTWaiter.subsystemQueue.sync {
            return _allExpectations
        }
    }
    
    internal func addExpectation(_ expectation: XCTestExpectation) {
        precondition(Thread.isMainThread, "\(#function) must be called on the main thread")
        precondition(currentWaiter == nil, "API violation - creating an expectation while already in waiting mode.")
        
        XCTWaiter.subsystemQueue.sync {
            _allExpectations.append(expectation)
        }
    }
    
    internal func cleanUpExpectations(_ expectationsToCleanUp: [XCTestExpectation]? = nil) {
        XCTWaiter.subsystemQueue.sync {
            if let expectationsToReset = expectationsToCleanUp {
                for expectation in expectationsToReset {
                    expectation.cleanUp()
                    _allExpectations.removeAll(where: { $0 == expectation })
                }
            } else {
                for expectation in _allExpectations {
                    expectation.cleanUp()
                }
                _allExpectations.removeAll()
            }
        }
    }
    
    /// An internal object implementing performance measurements.
    internal var _performanceMeter: PerformanceMeter?
    
    open override var testRunClass: AnyClass? {
        return XCTestCaseRun.self
    }
    
    open override func perform(_ run: XCTestRun) {
        guard let testRun = run as? XCTestCaseRun else {
            fatalError("Wrong XCTestRun class.")
        }
        
        XCTCurrentTestCase = self
        testRun.start()
        invokeTest()
        failIfExpectationsNotWaitedFor(_allExpectations)
        testRun.stop()
        XCTCurrentTestCase = nil
    }
    
    /// The designated initializer for SwiftXCTest's XCTestCase.
    /// - Note: Like the designated initializer for Apple XCTest's XCTestCase,
    ///   `-[XCTestCase initWithInvocation:]`, it's rare for anyone outside of
    ///   XCTest itself to call this initializer.
    public required init(name: String, testClosure: @escaping XCTestCaseClosure) {
        _name = "\(type(of: self)).\(name)"
        self.testClosure = testClosure
    }
    
    // Invoking a test performs its setup, invocation, and teardown. In general this should not be called directly.
    open func invokeTest() {
        performSetUpSequence()
        
        // 在, OC 版本里面, 是 invocation.invoke 执行的各自的方法. 在这里, 使用了 testClosure
        do {
            if skip == nil {
                try testClosure(self)
            }
        } catch {
            if error.xct_shouldRecordAsTestFailure {
                recordFailure(for: error)
            }
            
            if error.xct_shouldRecordAsTestSkip {
                if let skip = error as? XCTSkip {
                    self.skip = skip
                } else {
                    self.skip = XCTSkip(error: error, message: nil, sourceLocation: nil)
                }
            }
        }
        
        if let skip = skip {
            testRun?.recordSkip(description: skip.summary, sourceLocation: skip.sourceLocation)
        }
        
        performTearDownSequence()
    }
    
    // 当一个 testCase 出错了之后, 要记录到 testRun 里面, 然后, 判断是不是应该继续执行.
    open func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        testRun?.recordFailure(
            withDescription: description,
            inFile: filePath,
            atLine: lineNumber,
            expected: expected)
        
        // 当发生错误之后, 就停掉性能的监控.
        _performanceMeter?.abortMeasuring()
        
        // FIXME: Apple XCTest does not throw a fatal error and crash the test
        //        process, it merely prevents the remainder of a testClosure
        //        from expecting after it's been determined that it has already
        //        failed. The following behavior is incorrect.
        // FIXME: No regression tests exist for this feature. We may break it
        //        without ever realizing.
        if !continueAfterFailure {
            // 是否发生错误之后, 就立马进行退出.
            fatalError("Terminating execution due to test failure")
        }
    }
    
    // Convenience for recording failure using a SourceLocation
    func recordFailure(description: String, at sourceLocation: SourceLocation, expected: Bool) {
        recordFailure(withDescription: description, inFile: sourceLocation.file, atLine: Int(sourceLocation.line), expected: expected)
    }
    
    // Convenience for recording a failure for a caught Error
    private func recordFailure(for error: Error) {
        recordFailure(
            withDescription: "threw error \"\(error)\"",
            inFile: "<EXPR>",
            atLine: 0,
            expected: false)
    }
    
    /// Setup method called before the invocation of any test method in the
    /// class.
    open class func setUp() {}
    
    /// Teardown method called after the invocation of every test method in the
    /// class.
    open class func tearDown() {}
    
    private var teardownBlocks: [() -> Void] = []
    private var teardownBlocksDequeued: Bool = false
    private let teardownBlocksQueue: DispatchQueue = DispatchQueue(label: "org.swift.XCTest.XCTestCase.teardownBlocks")
    
    /// Registers a block of teardown code to be run after the current test
    /// method ends.
    open func addTeardownBlock(_ block: @escaping () -> Void) {
        teardownBlocksQueue.sync {
            precondition(!self.teardownBlocksDequeued, "API violation -- attempting to add a teardown block after teardown blocks have been dequeued")
            self.teardownBlocks.append(block)
        }
    }
    
    // Before each test begins, XCTest calls setUpWithError(), followed by setUp(). If state preparation might throw errors, override setUpWithError().
    // XCTest marks the test failed when it catches errors, or skipped when it catches XCTSkip.
    private func performSetUpSequence() {
        do {
            try setUpWithError()
        } catch {
            if error.xct_shouldRecordAsTestFailure {
                recordFailure(for: error)
            }
            
            if error.xct_shouldSkipTestInvocation {
                if let skip = error as? XCTSkip {
                    self.skip = skip
                } else {
                    self.skip = XCTSkip(error: error, message: nil, sourceLocation: nil)
                }
            }
        }
        
        setUp()
    }
    
    private func performTearDownSequence() {
        // 先执行加入到 Teardown 里面的各个 bock.
        runTeardownBlocks()
        
        tearDown()
        
        do {
            try tearDownWithError()
        } catch {
            if error.xct_shouldRecordAsTestFailure {
                recordFailure(for: error)
            }
        }
    }
    
    private func runTeardownBlocks() {
        let blocks = teardownBlocksQueue.sync {
            () -> [() -> Void] in
            self.teardownBlocksDequeued = true
            let blocks = self.teardownBlocks
            self.teardownBlocks = []
            return blocks
        }
        
        for block in blocks.reversed() {
            block()
        }
    }
    
    open var continueAfterFailure: Bool {
        get {
            return true
        }
        set {
            // TODO: When using the Objective-C runtime, XCTest is able to throw an exception from an assert and then catch it at the frame above the test method.
            //      This enables the framework to effectively stop all execution in the current test.
            //      There is no such facility in Swift. Until we figure out how to get a compatible behavior,
            //      we have decided to hard-code the value of 'true' for continue after failure.
        }
    }
}

// 传入一个类型的所有类型方法, 返回一个 XCTestCaseEntry
public func testCase<T: XCTestCase>(_ allTests: [(String, (T) -> () throws -> Void)]) -> XCTestCaseEntry {
    let tests: [(String, XCTestCaseClosure)] = allTests.map { ($0.0, test($0.1)) }
    return (T.self, tests)
}

// 传入一个类型的所有类型方法, 返回一个 XCTestCaseEntry
public func testCase<T: XCTestCase>(_ allTests: [(String, (T) -> () -> Void)]) -> XCTestCaseEntry {
    let tests: [(String, XCTestCaseClosure)] = allTests.map { ($0.0, test($0.1)) }
    return (T.self, tests)
}

// 从类型中, 抽取成员方法的过程.
// 就是传入对象, 返回成员方法, 然后调用成员方法.
private func test<T: XCTestCase>(_ testFunc: @escaping (T) -> () throws -> Void) -> XCTestCaseClosure {
    return { testCaseType in
        guard let testCase = testCaseType as? T else {
            fatalError("Attempt to invoke test on class \(T.self) with incompatible instance type \(type(of: testCaseType))")
        }
        try testFunc(testCase)()
    }
}
