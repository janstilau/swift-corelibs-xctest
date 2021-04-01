/// A test run for an `XCTestSuite`.
open class XCTestSuiteRun: XCTestRun {
    // 所有的 case 的总和.
    open override var totalDuration: TimeInterval {
        return testRuns.reduce(TimeInterval(0.0)) { $0 + $1.totalDuration }
    }

    /// The combined execution count of each test case run in the suite.
    open override var executionCount: Int {
        return testRuns.reduce(0) { $0 + $1.executionCount }
    }

    /// The combined skip count of each test case run in the suite.
    open override var skipCount: Int {
        testRuns.reduce(0) { $0 + $1.skipCount }
    }

    /// The combined failure count of each test case run in the suite.
    open override var failureCount: Int {
        return testRuns.reduce(0) { $0 + $1.failureCount }
    }

    /// The combined unexpected failure count of each test case run in the
    /// suite.
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

    /// The test run for each of the tests in this suite.
    /// Depending on what kinds of tests this suite is composed of, these could
    /// be some combination of `XCTestCaseRun` and `XCTestSuiteRun` objects.
    open private(set) var testRuns = [XCTestRun]()

    /// Add a test run to the collection of `testRuns`.
    /// - Note: It is rare to call this method outside of XCTest itself.
    open func addTestRun(_ testRun: XCTestRun) {
        testRuns.append(testRun)
    }

    private var testSuite: XCTestSuite {
        return test as! XCTestSuite
    }
}
