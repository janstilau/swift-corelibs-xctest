
open class XCTest {
    open var name: String {
        fatalError("Must be overridden by subclasses.")
    }
    
    open var testCaseCount: Int {
        fatalError("Must be overridden by subclasses.")
    }
    
    open var testRunClass: AnyClass? {
        fatalError("Must be overridden by subclasses.")
    }
    
    open private(set) var testRun: XCTestRun? = nil
    
    // 各个子类, 重写该方法. 完成模板模式各个 item 的覆盖.
    // 固定会, 调用 run 的 start, 调用自己的 setup, test, teardown, 调用 run 的 stop
    // 其中, 会记录下其中出现的各个错误.
    open func perform(_ run: XCTestRun) {
        fatalError("Must be overridden by subclasses.")
    }
    
    // 一个固定的模式, 根据自己的类型, 创建各自的 run, 然后调用 perform.
    open func run() {
        guard let testRunType = testRunClass as? XCTestRun.Type else {
            fatalError("XCTest.testRunClass must be a kind of XCTestRun.")
        }
        testRun = testRunType.init(test: self)
        perform(testRun!)
    }
    
    open func setUpWithError() throws {}
    
    open func setUp() {}
    
    open func tearDown() {}
    
    open func tearDownWithError() throws {}
    
    public init() {}
}
