
// 和一个 class 挂钩的 XCTestCaseSuite, 根据类的信息, 进行 [test] 的填充, 并调用类的 setup, teardown 方法.
internal class XCTestCaseSuite: XCTestSuite {
    private let testCaseClass: XCTestCase.Type

    init(testCaseEntry: XCTestCaseEntry) {
        let testCaseClass = testCaseEntry.testCaseClass
        self.testCaseClass = testCaseClass
        super.init(name: String(describing: testCaseClass))

        for (testName, testClosure) in testCaseEntry.allTests {
            let testCase = testCaseClass.init(name: testName, testClosure: testClosure)
            addTest(testCase)
        }
    }

    override func setUp() {
        testCaseClass.setUp()
    }

    override func tearDown() {
        testCaseClass.tearDown()
    }
}
