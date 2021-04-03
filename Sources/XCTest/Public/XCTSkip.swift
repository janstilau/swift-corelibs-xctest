// 在 setupWithError 内部, 如果要跳过, 就生成这个 error 就可以了.
public struct XCTSkip: Error {

    public let message: String?
    let sourceLocation: SourceLocation?
    let summary: String
    private let explanation: String?

    private init(explanation: String?, message: String?, sourceLocation: SourceLocation?) {
        self.explanation = explanation
        self.message = message
        self.sourceLocation = sourceLocation

        var summary = "Test skipped"
        if let explanation = explanation {
            summary += ": \(explanation)"
        }
        if let message = message, !message.isEmpty {
            summary += " - \(message)"
        }
        self.summary = summary
    }

    public init(_ message: @autoclosure () -> String? = nil, file: StaticString = #file, line: UInt = #line) {
        self.init(explanation: nil, message: message(), sourceLocation: SourceLocation(file: file, line: line))
    }

    fileprivate init(expectedValue: Bool, message: String?, file: StaticString, line: UInt) {
        let explanation = expectedValue
            ? "required true value but got false"
            : "required false value but got true"
        self.init(explanation: explanation, message: message, sourceLocation: SourceLocation(file: file, line: line))
    }

    internal init(error: Error, message: String?, sourceLocation: SourceLocation?) {
        let explanation = #"threw error "\#(error)""#
        self.init(explanation: explanation, message: message, sourceLocation: sourceLocation)
    }

}

extension XCTSkip: XCTCustomErrorHandling {

    var shouldRecordAsTestFailure: Bool {
        false
    }

    var shouldRecordAsTestSkip: Bool {
        true
    }

}


// 外界, 使用更加友好的方法.
public func XCTSkipIf(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String? = nil,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    // 这里使用 try, 是因为 skipIfEqual 为 throws
    // 因为没有 catch, 所以整个函数是 throws
    // expression 没有实际调用, 这里是两个 autoclosure 的传递.
    try skipIfEqual(expression(), true, message(), file: file, line: line)
}

// 外界, 使用更加友好的方法.
public func XCTSkipUnless(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String? = nil,
    file: StaticString = #file, line: UInt = #line
) throws {
    // 这里使用 try, 是因为 skipIfEqual 为 throws
    // 因为没有 catch, 所以整个函数是 throws
    // expression 没有实际调用, 这里是两个 autoclosure 的传递.
    try skipIfEqual(expression(), false, message(), file: file, line: line)
}

// 内部, 将方法进行统一.
private func skipIfEqual(
    _ expression: @autoclosure () throws -> Bool,
    _ expectedValue: Bool,
    _ message: @autoclosure () -> String?,
    file: StaticString,
    line: UInt
) throws {
    let expressionValue: Bool

    // 如果, expression 执行捕捉到了错误, 那么生成 XCTSkip 记载错误
    do {
        expressionValue = try expression()
    } catch {
        throw XCTSkip(error: error,
                      message: message(),
                      sourceLocation: SourceLocation(file: file, line: line))
    }

    // 如果, expression 正常执行, 比较结果和 expectedValue 一样, 那么生成 XCTSkip 记载符合条件.
    if expressionValue == expectedValue {
        throw XCTSkip(expectedValue: expectedValue,
                      message: message(),
                      file: file,
                      line: line)
    }
}
