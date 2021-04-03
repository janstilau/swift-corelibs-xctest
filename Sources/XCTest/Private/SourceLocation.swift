

// 就是对于 File line 这两个数据的包装而已.
internal struct SourceLocation {

    typealias LineNumber = UInt

    // 一个类方法, 返回常用的对象.
    static var unknown: SourceLocation = {
        return SourceLocation(file: "<unknown>", line: 0)
    }()

    let file: String
    let line: LineNumber

    init(file: String, line: LineNumber) {
        self.file = file
        self.line = line
    }

    init(file: StaticString, line: LineNumber) {
        self.init(file: String(describing: file), line: line)
    }

    init(file: String, line: Int) {
        self.init(file: file, line: LineNumber(line))
    }

    init(file: StaticString, line: Int) {
        self.init(file: String(describing: file), line: LineNumber(line))
    }

}
