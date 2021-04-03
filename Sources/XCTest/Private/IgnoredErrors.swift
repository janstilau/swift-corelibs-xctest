protocol XCTCustomErrorHandling: Error {

    /// Whether this error should be recorded as a test failure when it is caught. Default: true.
    var shouldRecordAsTestFailure: Bool { get }

    /// Whether this error should cause the test invocation to be skipped when it is caught during a throwing setUp method. Default: true.
    var shouldSkipTestInvocation: Bool { get }

    /// Whether this error should be recorded as a test skip when it is caught during a test invocation. Default: false.
    var shouldRecordAsTestSkip: Bool { get }

}

// 都有默认实现. 所以, 上面的几个方法, 都是 Optinal 的.
extension XCTCustomErrorHandling {

    var shouldRecordAsTestFailure: Bool {
        true
    }

    var shouldSkipTestInvocation: Bool {
        true
    }

    var shouldRecordAsTestSkip: Bool {
        false
    }

}

extension Error {

    var xct_shouldRecordAsTestFailure: Bool {
        (self as? XCTCustomErrorHandling)?.shouldRecordAsTestFailure ?? true
    }

    var xct_shouldSkipTestInvocation: Bool {
        (self as? XCTCustomErrorHandling)?.shouldSkipTestInvocation ?? true
    }

    var xct_shouldRecordAsTestSkip: Bool {
        (self as? XCTCustomErrorHandling)?.shouldRecordAsTestSkip ?? false
    }

}

/// The error type thrown by `XCTUnwrap` on assertion failure.
internal struct XCTestErrorWhileUnwrappingOptional: Error, XCTCustomErrorHandling {

    var shouldRecordAsTestFailure: Bool {
        // Don't record this error as a test failure, because XCTUnwrap
        // internally records the failure before throwing this error
        false
    }

}
