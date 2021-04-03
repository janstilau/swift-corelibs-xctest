
// Composite 层, 相应的属性, 都变为了对于 Component 层的累加处理.
// 大量使用了 reduce 函数.
open class XCTestSuiteRun: XCTestRun {
        
    // 这里面, 存的是接口对象. 所以, XCTestSuite 是复合的概念. 可能是一个 case, 也可能是一个 suite.
    open private(set) var testRuns = [XCTestRun]()
    
    open override var totalDuration: TimeInterval {
        return testRuns.reduce(TimeInterval(0.0)) { $0 + $1.totalDuration }
    }

    open override var executionCount: Int {
        return testRuns.reduce(0) { $0 + $1.executionCount }
    }

    open override var skipCount: Int {
        testRuns.reduce(0) { $0 + $1.skipCount }
    }

    open override var failureCount: Int {
        return testRuns.reduce(0) { $0 + $1.failureCount }
    }

    open override var unexpectedExceptionCount: Int {
        return testRuns.reduce(0) { $0 + $1.unexpectedExceptionCount }
    }

    open override func start() {
        super.start()
        XCTestObservationCenter.shared.testSuiteWillStart(testSuite)
    }

    open override func stop() {
        super.stop()
        XCTestObservationCenter.shared.testSuiteDidFinish(testSuite)
    }

    open func addTestRun(_ testRun: XCTestRun) {
        testRuns.append(testRun)
    }

    private var testSuite: XCTestSuite {
        return test as! XCTestSuite
    }
}
