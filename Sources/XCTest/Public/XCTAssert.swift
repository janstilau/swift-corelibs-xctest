
// 这个 enum, 更多的是当做一个 Type 来用.
// 将这个 type 的描述, 也就是 name, 内含在这个 Type 里面. 这样的设计, 更加的面向对象.
private enum _XCTAssertion {
    case equal
    case equalWithAccuracy
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case notEqual
    case notEqualWithAccuracy
    case `nil`
    case notNil
    case unwrap
    case `true`
    case `false`
    case fail
    case throwsError
    case noThrow

    var name: String? {
        switch(self) {
        case .equal: return "XCTAssertEqual"
        case .equalWithAccuracy: return "XCTAssertEqual"
        case .greaterThan: return "XCTAssertGreaterThan"
        case .greaterThanOrEqual: return "XCTAssertGreaterThanOrEqual"
        case .lessThan: return "XCTAssertLessThan"
        case .lessThanOrEqual: return "XCTAssertLessThanOrEqual"
        case .notEqual: return "XCTAssertNotEqual"
        case .notEqualWithAccuracy: return "XCTAssertNotEqual"
        case .`nil`: return "XCTAssertNil"
        case .notNil: return "XCTAssertNotNil"
        case .unwrap: return "XCTUnwrap"
        case .`true`: return "XCTAssertTrue"
        case .`false`: return "XCTAssertFalse"
        case .throwsError: return "XCTAssertThrowsError"
        case .noThrow: return "XCTAssertNoThrow"
        case .fail: return nil
        }
    }
}

private enum _XCTAssertionResult {
    case success
    case expectedFailure(String?) // 执行顺利完成, 和 Assert 想要的结果不符, 算作 expectedFailure
    case unexpectedFailure(Swift.Error) // 在执行的过程中, 发生了 error, 算作 unexpectedFailure

    // 所执行函数, 有没有正常执行完毕.
    var isExpected: Bool {
        switch self {
        case .unexpectedFailure(_): return false
        default: return true
        }
    }

    func failureDescription(_ assertion: _XCTAssertion) -> String {
        let explanation: String
        switch self {
        case .success: explanation = "passed"
        // 这两个 case 一样, 一个有值, 一个没有值.
        case .expectedFailure(let details?): explanation = "failed: \(details)"
        case .expectedFailure(_): explanation = "failed"
        case .unexpectedFailure(let error): explanation = "threw error \"\(error)\""
        }

        if let name = assertion.name {
            return "\(name) \(explanation)"
        } else {
            return explanation
        }
    }
}

// assertion 仅仅是为了在 withDescription 生成有效的信息, 对于流程控制没有太大的关系.
// 真正重要的, 是 expression. 如果, try expression() 发生了错误, 就是 unexpectedFailure.
// 如果, try expression() 的结果, 是 expectedFailure, 就是不满足 assert 的语义
// 如果, try expression() 成功了, 就是正确了.
private func _XCTEvaluateAssertion(_ assertion: _XCTAssertion,
                                   message: @autoclosure () -> String = "",
                                   file: StaticString = #file,
                                   line: UInt = #line,
                                   expression: () throws -> _XCTAssertionResult) {
    let result: _XCTAssertionResult
    do {
        result = try expression()
    } catch {
        // 如果, 发生了 error, 那么就是 unexpectedFailure
        result = .unexpectedFailure(error)
    }

    switch result {
    case .success:
        return
    default:
        // Assert 的作用, 就在这里, 如果返回的 result 不是 success 这种 type 的, 就调用 recordFailure 方法, 这个方法, 会在 run 里面, 标记当前的这个 testCase 失败了.
        if let currentTestCase = XCTCurrentTestCase {
            currentTestCase.recordFailure(
                withDescription: "\(result.failureDescription(assertion)) - \(message())",
                inFile: String(describing: file),
                atLine: Int(line),
                expected: result.isExpected)
        }
    }
}


public func XCTAssert(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(try expression(), message(), file: file, line: line)
}

// Equal, 就直接是两个值进行 == 比较了. 至于这两个值, == 到底什么逻辑, 是这个类型自己的实现.
public func XCTAssertEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T,
                                         _ expression2: @autoclosure () throws -> T,
                                         _ message: @autoclosure () -> String = "",
                                         file: StaticString = #file,
                                         line: UInt = #line) {
    _XCTEvaluateAssertion(.equal, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if value1 == value2 {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is not equal to (\"\(value2)\")")
        }
    }
}


private func areEqual<T: Numeric>(_ exp1: T, _ exp2: T, accuracy: T) -> Bool {
    // Test with equality first to handle comparing inf/-inf with itself.
    if exp1 == exp2 {
        return true
    } else {
        // NaN values are handled implicitly, since the <= operator returns false when comparing any value to NaN.
        let difference = (exp1.magnitude > exp2.magnitude) ? exp1 - exp2 : exp2 - exp1
        return difference.magnitude <= accuracy.magnitude
    }
}

public func XCTAssertEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T,
                                             _ expression2: @autoclosure () throws -> T,
                                             accuracy: T,
                                             _ message: @autoclosure () -> String = "",
                                             file: StaticString = #file,
                                             line: UInt = #line) {
    _XCTAssertEqual(try expression1(), try expression2(), accuracy: accuracy, message(), file: file, line: line)
}

public func XCTAssertEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T,
                                       _ expression2: @autoclosure () throws -> T,
                                       accuracy: T,
                                       _ message: @autoclosure () -> String = "",
                                       file: StaticString = #file,
                                       line: UInt = #line) {
    _XCTAssertEqual(try expression1(), try expression2(), accuracy: accuracy, message(), file: file, line: line)
}

private func _XCTAssertEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.equalWithAccuracy, message: message(), file: file, line: line)
    {
        let (value1, value2) = (try expression1(), try expression2())
        if areEqual(value1, value2, accuracy: accuracy) {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is not equal to (\"\(value2)\") +/- (\"\(accuracy)\")")
        }
    }
}

// 这里, 方法标记为 deprecated, 在 deprecated 方法里面, 调用了当前版本的 方法.
@available(*, deprecated, renamed: "XCTAssertEqual(_:_:accuracy:file:line:)")
public func XCTAssertEqualWithAccuracy<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(try expression1(), try expression2(), accuracy: accuracy, message(), file: file, line: line)
}

public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool,
                          _ message: @autoclosure () -> String = "",
                          file: StaticString = #file,
                          line: UInt = #line) {
    _XCTEvaluateAssertion(.`true`,
                          message: message(),
                          file: file,
                          line: line) {
        let value = try expression()
        if value {
            return .success
        } else {
            return .expectedFailure(nil)
        }
    }
}

public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.`false`, message: message(), file: file, line: line) {
        let value = try expression()
        if !value {
            return .success
        } else {
            return .expectedFailure(nil)
        }
    }
}

public func XCTAssertGreaterThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.greaterThan, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if value1 > value2 {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is not greater than (\"\(value2)\")")
        }
    }
}

public func XCTAssertGreaterThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.greaterThanOrEqual, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if value1 >= value2 {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is less than (\"\(value2)\")")
        }
    }
}

public func XCTAssertLessThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.lessThan, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if value1 < value2 {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is not less than (\"\(value2)\")")
        }
    }
}

public func XCTAssertLessThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.lessThanOrEqual, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if value1 <= value2 {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is greater than (\"\(value2)\")")
        }
    }
}

public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.`nil`, message: message(), file: file, line: line) {
        let value = try expression()
        if value == nil {
            return .success
        } else {
            return .expectedFailure("\"\(value!)\"")
        }
    }
}

public func XCTAssertNotEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.notEqual, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if value1 != value2 {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is equal to (\"\(value2)\")")
        }
    }
}

public func XCTAssertNotEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTAssertNotEqual(try expression1(), try expression2(), accuracy: accuracy, message(), file: file, line: line)
}

public func XCTAssertNotEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTAssertNotEqual(try expression1(), try expression2(), accuracy: accuracy, message(), file: file, line: line)
}

private func _XCTAssertNotEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.notEqualWithAccuracy, message: message(), file: file, line: line) {
        let (value1, value2) = (try expression1(), try expression2())
        if !areEqual(value1, value2, accuracy: accuracy) {
            return .success
        } else {
            return .expectedFailure("(\"\(value1)\") is equal to (\"\(value2)\") +/- (\"\(accuracy)\")")
        }
    }
}

@available(*, deprecated, renamed: "XCTAssertNotEqual(_:_:accuracy:file:line:)")
public func XCTAssertNotEqualWithAccuracy<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertNotEqual(try expression1(), try expression2(), accuracy: accuracy, message(), file: file, line: line)
}

public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.notNil, message: message(), file: file, line: line) {
        let value = try expression()
        if value != nil {
            return .success
        } else {
            return .expectedFailure(nil)
        }
    }
}

/// Asserts that an expression is not `nil`, and returns its unwrapped value.
///
/// Generates a failure if `expression` returns `nil`.
///
/// - Parameters:
///   - expression: An expression of type `T?` to compare against `nil`. Its type will determine the type of the
///     returned value.
///   - message: An optional description of the failure.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was
///     called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
/// - Returns: A value of type `T`, the result of evaluating and unwrapping the given `expression`.
/// - Throws: An error if `expression` returns `nil`. If `expression` throws an error, then that error will be rethrown instead.
public func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) throws -> T {
    var value: T?
    var caughtErrorOptional: Swift.Error?

    // 这里, 是使用 Block 的副作用, 实现的判断并且返回值的功能.
    _XCTEvaluateAssertion(.unwrap, message: message(), file: file, line: line) {
        do {
            value = try expression()
        } catch {
            caughtErrorOptional = error
            return .unexpectedFailure(error)
        }

        if value != nil {
            return .success
        } else {
            return .expectedFailure("expected non-nil value of type \"\(T.self)\"")
        }
    }

    if let unwrappedValue = value {
        return unwrappedValue
    } else if let error = caughtErrorOptional {
        throw error
    } else {
        throw XCTestErrorWhileUnwrappingOptional()
    }
}

public func XCTFail(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.fail, message: message, file: file, line: line) {
        return .expectedFailure(nil)
    }
}

public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, _ errorHandler: (_ error: Swift.Error) -> Void = { _ in }) {
    _XCTEvaluateAssertion(.throwsError, message: message(), file: file, line: line) {
        var caughtErrorOptional: Swift.Error?
        do {
            _ = try expression()
        } catch {
            caughtErrorOptional = error
        }

        if let caughtError = caughtErrorOptional {
            errorHandler(caughtError)
            return .success
        } else {
            return .expectedFailure("did not throw error")
        }
    }
}

public func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _XCTEvaluateAssertion(.noThrow, message: message(), file: file, line: line) {
        do {
             _ = try expression()
            return .success
        } catch let error {
            return .expectedFailure("threw error \"\(error)\"")
        }
    }
}
