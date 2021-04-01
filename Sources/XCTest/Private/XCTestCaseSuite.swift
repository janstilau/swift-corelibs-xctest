//  XCTestCaseSuite.swift
//  A test suite associated with a particular test case class.
//

/// A test suite which is associated with a particular test case class. It will
/// call `setUp` and `tearDown` on the class itself before and after invoking
/// all of the test cases making up the class.
internal class XCTestCaseSuite: XCTestSuite {
    private let testCaseClass: XCTestCase.Type

    init(testCaseEntry: XCTestCaseEntry) {
        let testCaseClass = testCaseEntry.testCaseClass
        self.testCaseClass = testCaseClass
        super.init(name: String(describing: testCaseClass))

        // 在这里, 添加了所有的测试用例. 就是类名, 和类下的所有测试方法.
        // 所以, 一个测试方法, 一个 testRun 对象;
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
