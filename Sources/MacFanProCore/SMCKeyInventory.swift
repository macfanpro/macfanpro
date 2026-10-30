import Foundation

/// Missing temperature keys may be skipped only after a complete successful
/// firmware enumeration. A failed ordinary read never means a sensor is absent.
struct SMCKeyInventory {
    private var keys: Set<String>?
    var complete: Bool { keys != nil }
    func mayContain(_ key: String) -> Bool { keys?.contains(key) ?? true }

    mutating func rebuild(count: UInt32,
                          now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                          keyAtIndex: (UInt32) -> String?) -> Bool {
        keys = nil
        guard count > 0, count < 100_000 else { return false }
        let deadline = now() + 0.1
        var found = Set<String>()
        for index in 0..<count {
            guard now() < deadline, let key = keyAtIndex(index), key.utf8.count == 4,
                  key.utf8.allSatisfy({ (32...126).contains($0) }),
                  found.insert(key).inserted else { return false }
        }
        guard now() <= deadline else { return false }
        keys = found
        return true
    }
}

/// A broken/unsupported enumeration cannot repeatedly stall the control queue.
/// Three attempts per wake/connection, with exponential backoff, then use fresh
/// uncached probing until the next explicit invalidation.
struct SMCInventoryRetry {
    private(set) var failures = 0
    private var retryAt: TimeInterval = 0
    func canAttempt(at now: TimeInterval) -> Bool { failures < 3 && now >= retryAt }
    mutating func failed(at now: TimeInterval) {
        failures += 1
        retryAt = now + min(60, 5 * pow(2, Double(failures - 1)))
    }
}
