//  XCTestRun.swift
//  A test run collects information about the execution of a test.
//

/// A test run collects information about the execution of a test. Failures in
/// explicit test assertions are classified as "expected", while failures from
/// unrelated or uncaught exceptions are classified as "unexpected".
/*
 这个类, 就是收集测试过程中的信息的.
 不符合 Assert 的, 被认为是 expectedFaile.
 在执行测试方法过程中, throw 了 error 的, 被认为是 unexpected Faile.
 这两种, 都被认为是 Fail.
 
 XCTestRun 有两个子类,
 XCTestCaseRun, 就是一个测试用例, 也就是一个类的一个 test 方法的信息.
 XCTestSuiteRun, 是一个容器, 里面有很多的 XCTestRun, 有可能是 XCTestCaseRun, 也有可能是 XCTestSuiteRun. 复合模式.
 */
open class XCTestRun {
    /// The test instance provided when the test run was initialized.
    public let test: XCTest

    open private(set) var startDate: Date?
    open private(set) var stopDate: Date?

    // 如果, 测试经历了完整的过程, 就 end - start, 不然就是 0
    // optinal 的状态标志, 让我们少了很多的标志成员变量的设置.
    open var totalDuration: TimeInterval {
        if let stop = stopDate, let start = startDate {
            return stop.timeIntervalSince(start)
        } else {
            return 0.0
        }
    }

    open var testDuration: TimeInterval {
        return totalDuration
    }

    open var testCaseCount: Int {
        return test.testCaseCount
    }

    open private(set) var executionCount: Int = 0

    /// The number of test skips recorded during the run.
    open var skipCount: Int {
        hasBeenSkipped ? 1 : 0
    }

    /// The number of test failures recorded during the run.
    open private(set) var failureCount: Int = 0

    /// The number of uncaught exceptions recorded during the run.
    open private(set) var unexpectedExceptionCount: Int = 0

    /// The total number of test failures and uncaught exceptions recorded
    /// during the run.
    open var totalFailureCount: Int {
        return failureCount + unexpectedExceptionCount
    }

    /// `true` if all tests in the run completed their execution without
    /// recording any failures, otherwise `false`.
    open var hasSucceeded: Bool {
        guard isStopped else {
            return false
        }
        return totalFailureCount == 0
    }

    /// `true` if the test was skipped, otherwise `false`.
    open private(set) var hasBeenSkipped = false

    /// Designated initializer for the XCTestRun class.
    /// - Parameter test: An XCTest instance.
    /// - Returns: A test run for the provided test.
    public required init(test: XCTest) {
        self.test = test
    }

    /// Start a test run. Must not be called more than once.
    open func start() {
        guard !isStarted else {
            fatalError("Invalid attempt to start a test run that has " +
                       "already been started: \(self)")
        }
        guard !isStopped else {
            fatalError("Invalid attempt to start a test run that has " +
                       "already been stopped: \(self)")
        }
        
        // 基类 run, start 开始计时.
        startDate = Date()
    }

    /// Stop a test run. Must not be called unless the run has been started.
    /// Must not be called more than once.
    open func stop() {
        guard isStarted else {
            fatalError("Invalid attempt to stop a test run that has " +
                       "not yet been started: \(self)")
        }
        guard !isStopped else {
            fatalError("Invalid attempt to stop a test run that has " +
                       "already been stopped: \(self)")
        }

        executionCount += 1
        stopDate = Date()
    }

    // 当, 发生了错误之后, 将错误的信息, 记录到 testRun 里面.
    func recordFailure(withDescription description: String, inFile filePath: String?, atLine lineNumber: Int, expected: Bool) {
        func failureLocation() -> String {
            if let filePath = filePath {
                return "\(test.name) (\(filePath):\(lineNumber))"
            } else {
                return "\(test.name)"
            }
        }

        guard isStarted else {
            fatalError("Invalid attempt to record a failure for a test run " +
                       "that has not yet been started: \(failureLocation())")
        }
        guard !isStopped else {
            fatalError("Invalid attempt to record a failure for a test run " +
                       "that has already been stopped: \(failureLocation())")
        }

        // 根据是否是 expected, 增加不同的 int 成员变量.
        if expected {
            failureCount += 1
        } else {
            unexpectedExceptionCount += 1
        }
    }

    func recordSkip(description: String, sourceLocation: SourceLocation?) {
        func failureLocation() -> String {
            if let sourceLocation = sourceLocation {
                return "\(test.name) (\(sourceLocation.file):\(sourceLocation.line))"
            } else {
                return "\(test.name)"
            }
        }

        guard isStarted else {
            fatalError("Invalid attempt to record a skip for a test run " +
                       "that has not yet been started: \(failureLocation())")
        }
        guard !hasBeenSkipped else {
            fatalError("Invalid attempt to record a skip for a test run " +
                       "that has already been skipped: \(failureLocation())")
        }
        guard !isStopped else {
            fatalError("Invalid attempt to record a skip for a test run " +
                       "has already been stopped: \(failureLocation())")
        }

        hasBeenSkipped = true
    }

    private var isStarted: Bool {
        return startDate != nil
    }

    private var isStopped: Bool {
        return isStarted && stopDate != nil
    }
}
