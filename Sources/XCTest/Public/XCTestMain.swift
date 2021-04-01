// 这里, 框架暴露出来的, 看起来是为了外界使用的.
// 到底, 怎么从类里面获取对应的方法信息, 这里没有明确的写出来.
/// Starts a test run for the specified test cases.
///
/// This function will not return. If the test cases pass, then it will call `exit(EXIT_SUCCESS)`. If there is a failure, then it will call `exit(EXIT_FAILURE)`.
/// Example usage:
///
///     class TestFoo: XCTestCase {
///         static var allTests = {
///             return [
///                 ("test_foo", test_foo),
///                 ("test_bar", test_bar),
///             ]
///         }()
///
///         func test_foo() {
///             // Test things...
///         }
///
///         // etc...
///     }
///
///// testCase
///     XCTMain([ testCase(TestFoo.allTests) ]) // testCase 定义在 XCTestCase 里面.
///
/// Command line arguments can be used to select a particular test case or class to execute. For example:
///
///     ./FooTests FooTestCase/testFoo  # Run a single test case
///     ./FooTests FooTestCase          # Run all the tests in FooTestCase
///
public func XCTMain(_ testCases: [XCTestCaseEntry]) -> Never {
    XCTMain(testCases, arguments: CommandLine.arguments)
}

public func XCTMain(_ testCases: [XCTestCaseEntry], arguments: [String]) -> Never {
    XCTMain(testCases, arguments: arguments, observers: [PrintObserver()])
}

public func XCTMain(
    _ testCases: [XCTestCaseEntry],
    arguments: [String],
    observers: [XCTestObservation]
) -> Never {
    let testBundle = Bundle.main

    let executionMode = ArgumentParser(arguments: arguments).executionMode

    // Apple XCTest behaves differently if tests have been filtered:
    // - The root `XCTestSuite` is named "Selected tests" instead of
    //   "All tests".
    // - An `XCTestSuite` representing the .xctest test bundle is not included.
    
    let rootTestSuite: XCTestSuite
    let currentTestSuite: XCTestSuite
    
    if executionMode.selectedTestNames == nil {
        rootTestSuite = XCTestSuite(name: "All tests")
        currentTestSuite = XCTestSuite(name: "\(testBundle.bundleURL.lastPathComponent).xctest")
        rootTestSuite.addTest(currentTestSuite)
    } else {
        rootTestSuite = XCTestSuite(name: "Selected tests")
        currentTestSuite = rootTestSuite
    }

    let filter = TestFiltering(selectedTestNames: executionMode.selectedTestNames)
    // 这里是通道的写法, filterTests 的返回值, map, 然后 forEach, 然后在 ForEach 里面, 修改了 currentTestSuite 的值.
    TestFiltering.filterTests(testCases, filter: filter.selectedTestFilter)
        .map(XCTestCaseSuite.init) // 在这里, 根据每个类的类对象, 以及方法, 生成了一个 XCTestCaseSuite
        .forEach(currentTestSuite.addTest)

    switch executionMode {
    case .list(type: .humanReadable):
        TestListing(testSuite: rootTestSuite).printTestList()
        
        exit(EXIT_SUCCESS)
    case .list(type: .json):
        TestListing(testSuite: rootTestSuite).printTestJSON()
        
        exit(EXIT_SUCCESS)
    case let .help(invalidOption):
        
        if let invalid = invalidOption {
            let errMsg = "Error: Invalid option \"\(invalid)\"\n"
            FileHandle.standardError.write(errMsg.data(using: .utf8) ?? Data())
        }
        let exeName = URL(fileURLWithPath: arguments[0]).lastPathComponent
        let sampleTest = rootTestSuite.list().first ?? "Tests.FooTestCase/testFoo"
        let sampleTests = sampleTest.prefix(while: { $0 != "/" })
        exit(invalidOption == nil ? EXIT_SUCCESS : EXIT_FAILURE)
    case .run(selectedTestNames: _):
        // Add a test observer that prints test progress to stdout.
        let observationCenter = XCTestObservationCenter.shared
        // 将, 监听器加载 observationCenter 中.
        for observer in observers {
            observationCenter.addTestObserver(observer)
        }

        observationCenter.testBundleWillStart(testBundle)
        rootTestSuite.run()
        observationCenter.testBundleDidFinish(testBundle)

        // 然后判断, 是否有失败的个数.
        exit(rootTestSuite.testRun!.totalFailureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}
