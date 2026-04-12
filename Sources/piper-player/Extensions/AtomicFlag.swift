import Foundation

final class AtomicFlag: @unchecked Sendable {
    private var _value = false
    private let lock = NSLock()

    func setIfUnset() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _value { return false }
        _value = true
        return true
    }
}
