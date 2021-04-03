public typealias XCTestCaseClosure = (XCTestCase) throws -> Void

// 一个类所代表的所有测试方法模型. 挂钩了要测试类的类型, 各个测试方法, 以及对于各个测试方法调用的闭包.
public typealias XCTestCaseEntry = (testCaseClass: XCTestCase.Type,
                                    allTests: [(String, XCTestCaseClosure)])

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

private func test<T: XCTestCase>(_ testFunc: @escaping (T) -> () throws -> Void) -> XCTestCaseClosure {
    return { testCaseType in
        guard let testCase = testCaseType as? T else {
            fatalError("Attempt to invoke test on class \(T.self) with incompatible instance type \(type(of: testCaseType))")
        }
        try testFunc(testCase)()
    }
}










internal var XCTCurrentTestCase: XCTestCase?

// 这个类, 其实有点难理解.
// 在 XCTest Run 的时候, 一个 XCTestCase 对象, 其实代表了它其中一个 test 方法. XCMain 会将里面, 所有 test 开头的方法抽取出来, 有 5 个方法, 就创建 5 个对象.
// 但是我们定义的时候, 是将这 5 个方法, 都当做成员方法写在一起的, 所以, 从之前的经验我们判断, 是一个对象, 包含了五个方法的测试.
open class XCTestCase: XCTest {
    
    // designate, 最重要的成员, 其实就是 XCTestCaseClosure. 实际上, 这个就是代表着一个 Invocation.
    public required init(name: String, testClosure: @escaping XCTestCaseClosure) {
        _name = "\(type(of: self)).\(name)"
        self.testClosure = testClosure
    }
    
    private var _name: String
    private let testClosure: XCTestCaseClosure
    open override var name: String {
        return _name
    }
    
    
    
    private var skip: XCTSkip?
    
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
        XCTCurrentTestCase = self
        testRun.start()
        invokeTest()
        failIfExpectationsNotWaitedFor(_allExpectations)
        testRun.stop()
        XCTCurrentTestCase = nil
    }
    
    
    // Invoking a test performs its setup, invocation, and teardown. In general this should not be called directly.
    open func invokeTest() {
        performSetUpSequence()
        
        // 在, OC 版本里面, 是 invocation.invoke 执行的各自的方法. 在这里, 使用了 testClosure
        do {
            // 如果, setupWithError 里面发生了错误, 那么这里 skip 会有值.
            // 也就不能调用 testClosure 了.
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
        
        // 如果, skip 有值, 那么就通知 run 进行记录.
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
        
        // 如果, 已经记录了错误了, 是否退出测试.
        // 默认, 是所有的 case 都会跑一次, 所以, 没有走 fatalError 让进程退出.
        // 在 Xcode 里面, 应该就是根据各个 case 的 failure count, 判断是不是通过测试了.
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
    
    // 类的 setUp, tearDown
    open class func setUp() {}
    open class func tearDown() {}
    
    private var teardownBlocks: [() -> Void] = []
    private var teardownBlocksDequeued: Bool = false
    private let teardownBlocksQueue: DispatchQueue = DispatchQueue(label: "org.swift.XCTest.XCTestCase.teardownBlocks")
    
    open func addTeardownBlock(_ block: @escaping () -> Void) {
        teardownBlocksQueue.sync {
            self.teardownBlocks.append(block)
        }
    }
    
    /*
     Before each test begins, XCTest calls setUpWithError(), followed by setUp(). If state preparation might throw errors, override setUpWithError().
     XCTest marks the test failed when it catches errors, or skipped when it catches XCTSkip.
     */
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
        // 这里, 是 Queue 的一种新语法, 提交的 Block 的返回值, 可以成为 sync 的返回值.
        let blocks = teardownBlocksQueue.sync {
            () -> [() -> Void] in
            self.teardownBlocksDequeued = true
            let blocks = self.teardownBlocks
            self.teardownBlocks = []
            return blocks
        }
        
        // 反向执行.
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


