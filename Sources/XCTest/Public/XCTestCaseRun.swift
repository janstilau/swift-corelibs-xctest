


open class XCTestCaseRun: XCTestRun {
    // 增加了通知的调用
    open override func start() {
        super.start()
        XCTestObservationCenter.shared.testCaseWillStart(testCase)
    }
    
    // 增加了通知的调用
    open override func stop() {
        super.stop()
        XCTestObservationCenter.shared.testCaseDidFinish(testCase)
    }
    
    // 增加了对于通知的处理.
    open override func recordFailure(withDescription description: String, inFile filePath: String?, atLine lineNumber: Int, expected: Bool) {
        super.recordFailure(
            withDescription: "\(test.name) : \(description)",
            inFile: filePath,
            atLine: lineNumber,
            expected: expected)
        
        XCTestObservationCenter.shared.testCase(
            testCase,
            didFailWithDescription: description,
            inFile: filePath,
            atLine: lineNumber)
    }
    
    // 增加了对于通知的处理.
    override func recordSkip(description: String, sourceLocation: SourceLocation?) {
        super.recordSkip(description: description, sourceLocation: sourceLocation)
        
        // 通知 XCTestObservationCenter 发生了错误.
        XCTestObservationCenter.shared.testCase(
            testCase,
            wasSkippedWithDescription: description,
            at: sourceLocation)
    }
    
    private var testCase: XCTestCase {
        return test as! XCTestCase
    }
}
