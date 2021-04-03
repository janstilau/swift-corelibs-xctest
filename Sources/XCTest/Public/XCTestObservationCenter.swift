
// 为什么不用 static 呢, 这种写法, 又回到了 OC 时代, 静态变量当做类属性操作的写法了.
private let _sharedCenter: XCTestObservationCenter = XCTestObservationCenter()

public class XCTestObservationCenter {

    private var observers = Set<ObjectWrapper<XCTestObservation>>()

    public class var shared: XCTestObservationCenter {
        return _sharedCenter
    }

    public func addTestObserver(_ testObserver: XCTestObservation) {
        observers.insert(testObserver.wrapper)
    }

    public func removeTestObserver(_ testObserver: XCTestObservation) {
        observers.remove(testObserver.wrapper)
    }

    // 在固定的时间点, 通知消息中心, 由消息中心通知注册到内部的各个 observer .
    
    internal func testBundleWillStart(_ testBundle: Bundle) {
        forEachObserver { $0.testBundleWillStart(testBundle) }
    }

    internal func testSuiteWillStart(_ testSuite: XCTestSuite) {
        forEachObserver { $0.testSuiteWillStart(testSuite) }
    }

    internal func testCaseWillStart(_ testCase: XCTestCase) {
        forEachObserver { $0.testCaseWillStart(testCase) }
    }

    internal func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        forEachObserver { $0.testCase(testCase, didFailWithDescription: description, inFile: filePath, atLine: lineNumber) }
    }


    internal func testCaseDidFinish(_ testCase: XCTestCase) {
        forEachObserver { $0.testCaseDidFinish(testCase) }
    }

    internal func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        forEachObserver { $0.testSuiteDidFinish(testSuite) }
    }

    internal func testBundleDidFinish(_ testBundle: Bundle) {
        forEachObserver { $0.testBundleDidFinish(testBundle) }
    }

    // 遍历这个事情, 通用, 专门抽取成为方法.
    // 在 Swift 里面, 传入一个闭包的函数太常见了.
    private func forEachObserver(_ body: (XCTestObservation) -> Void) {
        for observer in observers {
            body(observer.object)
        }
    }
    
    internal func testCase(_ testCase: XCTestCase, wasSkippedWithDescription description: String, at sourceLocation: SourceLocation?) {
        forEachInternalObserver { $0.testCase(testCase, wasSkippedWithDescription: description, at: sourceLocation) }
    }
    
    internal func testCase(_ testCase: XCTestCase, didMeasurePerformanceResults results: String, file: StaticString, line: Int) {
        forEachInternalObserver { $0.testCase(testCase, didMeasurePerformanceResults: results, file: file, line: line) }
    }

    private func forEachInternalObserver(_ body: (XCTestInternalObservation) -> Void) {
        for observer in observers where observer.object is XCTestInternalObservation {
            body(observer.object as! XCTestInternalObservation)
        }
    }
}

private extension XCTestObservation {
    var wrapper: ObjectWrapper<XCTestObservation> {
        return ObjectWrapper(object: self, objectIdentifier: ObjectIdentifier(self))
    }
}
