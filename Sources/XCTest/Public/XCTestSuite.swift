//  XCTestSuite.swift
//  A collection of test cases.
//

/// A subclass of XCTest, XCTestSuite is a collection of test cases. Based on
/// what's passed into XCTMain(), a hierarchy of suites is built up, but
/// XCTestSuite can also be instantiated and manipulated directly:
///
///     let suite = XCTestSuite(name: "My Tests")
///     suite.addTest(myTest)
///     suite.testCaseCount // 1
///     suite.run()
open class XCTestSuite: XCTest {
    open private(set) var tests = [XCTest]()

    /// The name of this test suite.
    open override var name: String {
        return _name
    }
    /// A private setter for the name of this test suite.
    private let _name: String

    /// The number of test cases in this suite.
    open override var testCaseCount: Int {
        return tests.reduce(0) { $0 + $1.testCaseCount }
    }

    // Suite 容器, 返回自己作为 testRunClass
    open override var testRunClass: AnyClass? {
        return XCTestSuiteRun.self
    }

    open override func perform(_ run: XCTestRun) {
        guard let testRun = run as? XCTestSuiteRun else {
            fatalError("Wrong XCTestRun class.")
        }

        // run start, 基类会记录一下开始的时间, 然后, 两个子类的自定义代码, 都通知了一下 observerCenter.
        run.start()
        // setUp 方法, 基类空方法, case 子类, 应自定义. Suite 子类, 调用了记录的 Type 的 setup 类方法.
        // 这就是为什么 类方法会调用一次的原因,  是 suite 进行调用的.
        setUp()
        // 自己记录的各个 case 开始进行 run. 各个case 的 run 里面, 会建立自己的 xctestRun, 调用自己的任务的 perform.
        for test in tests {
            test.run()
            // suite 的 testRun 要负责收集各个 case 的 run 信息.
            testRun.addTestRun(test.testRun!)
        }
        // 收尾工作, 基类空方法, case 子类, 应自定义. Suite 子类, 调用了记录的 Type 的 TearDown 方法.
        tearDown()
        run.stop()
    }

    public init(name: String) {
        _name = name
    }

    /// Adds a test (either an `XCTestSuite` or an `XCTestCase` to this
    /// collection.
    open func addTest(_ test: XCTest) {
        tests.append(test)
    }
}
