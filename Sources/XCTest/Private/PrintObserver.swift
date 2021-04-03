// XCode 默认的测试 Observation, 就是 XCode 里面打印消息.
// XCode 里面的红色, 绿色是最后拿到结果之后, 根据各个 caseRun 的记录, 进行的界面显示. 和 XCTestObservation 无关.
internal class PrintObserver: XCTestObservation {
    func testBundleWillStart(_ testBundle: Bundle) {}

    func testSuiteWillStart(_ testSuite: XCTestSuite) {
        printAndFlush("Test Suite '\(testSuite.name)' started at \(dateFormatter.string(from: testSuite.testRun!.startDate!))")
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        printAndFlush("Test Case '\(testCase.name)' started at \(dateFormatter.string(from: testCase.testRun!.startDate!))")
    }

    func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        let file = filePath ?? "<unknown>"
        printAndFlush("\(file):\(lineNumber): error: \(testCase.name) : \(description)")
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        let testRun = testCase.testRun!

        let verb: String
        if testRun.hasSucceeded {
            if testRun.hasBeenSkipped {
                verb = "skipped"
            } else {
                verb = "passed"
            }
        } else {
            verb = "failed"
        }

        printAndFlush("Test Case '\(testCase.name)' \(verb) (\(formatTimeInterval(testRun.totalDuration)) seconds)")
    }

    func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        let testRun = testSuite.testRun!
        let verb = testRun.hasSucceeded ? "passed" : "failed"
        printAndFlush("Test Suite '\(testSuite.name)' \(verb) at \(dateFormatter.string(from: testRun.stopDate!))")

        let tests = testRun.executionCount == 1 ? "test" : "tests"
        let skipped = testRun.skipCount > 0 ? "\(testRun.skipCount) test\(testRun.skipCount != 1 ? "s" : "") skipped and " : ""
        let failures = testRun.totalFailureCount == 1 ? "failure" : "failures"

        printAndFlush("""
            \t Executed \(testRun.executionCount) \(tests), \
            with \(skipped)\
            \(testRun.totalFailureCount) \(failures) \
            (\(testRun.unexpectedExceptionCount) unexpected) \
            in \(formatTimeInterval(testRun.testDuration)) (\(formatTimeInterval(testRun.totalDuration))) seconds
            """
        )
    }

    func testBundleDidFinish(_ testBundle: Bundle) {}

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    fileprivate func printAndFlush(_ message: String) {
        print(message)
        #if !os(Android)
        fflush(stdout)
        #endif
    }

    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        return String(round(timeInterval * 1000.0) / 1000.0)
    }
}

extension PrintObserver: XCTestInternalObservation {
    func testCase(_ testCase: XCTestCase, wasSkippedWithDescription description: String, at sourceLocation: SourceLocation?) {
        let file = sourceLocation?.file ?? "<unknown>"
        let line = sourceLocation?.line ?? 0
        printAndFlush("\(file):\(line): \(testCase.name) : \(description)")
    }

    func testCase(_ testCase: XCTestCase, didMeasurePerformanceResults results: String, file: StaticString, line: Int) {
        printAndFlush("\(file):\(line): Test Case '\(testCase.name)' measured \(results)")
    }
}
