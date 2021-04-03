
open class XCTestSuite: XCTest {
    
    // 数据部分, 一组 XCTest
    // 因为 XCTest 是接口对象, 所以, XCTestSuite 其实是一个 Composite 层的东西.
    // 可能里面存储的是 XCTestCase, 那么 run 的时候, 就是各个测试用例了.
    // 也可能, 存储的是 XCTestSuite, 那么 run 的时候, 就是存储的 tests 里面的各个 test run. 例如, 一个类所有测试方法组合而成的 Suite
    // 也可能, 是一个 BundleSuite, 那么 tests 里面, 就是各个类的 Suite. run 的时候, 就是整个 Bundle 下所有类 run了.
    // 正是因为这样, bundle 的 run 收集了 bundle 的信息, 类的 run 手机了 类的信息, 类的测试方法 testCase 的 run, 收集了方法的信息.
    
    open private(set) var tests = [XCTest]()

    /// The name of this test suite.
    open override var name: String {
        return _name
    }
    /// A private setter for the name of this test suite.
    private let _name: String

    // 递归调用, 每一个层级, 都能拿到代表自己层级的 count.
    open override var testCaseCount: Int {
        return tests.reduce(0) { $0 + $1.testCaseCount }
    }

    // 记录 testRunClass, 使得整个类可以动态的创建 run 对象了.
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
