
// ObjectIdentifier 这个类, 仅仅是对于对象的 pointer 的封装.
internal struct ObjectWrapper<T>: Hashable {
    let object: T
    let objectIdentifier: ObjectIdentifier

    func hash(into hasher: inout Hasher) {
        hasher.combine(objectIdentifier)
    }
}

internal func ==<T>(lhs: ObjectWrapper<T>, rhs: ObjectWrapper<T>) -> Bool {
    return lhs.objectIdentifier == rhs.objectIdentifier
}
