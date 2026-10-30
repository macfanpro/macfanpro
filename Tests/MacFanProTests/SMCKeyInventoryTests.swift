import Foundation
import IOKit
import Testing
@testable import MacFanProCore

@Suite("Temperature key inventory — injected firmware only")
struct SMCKeyInventoryTests {
    @Test("Slow enumeration abandons its inventory instead of suppressing unread keys")
    func discoveryBudget() {
        var inventory = SMCKeyInventory()
        var clock = 0.0
        let complete = inventory.rebuild(count: 3, now: { clock }) { index in
            clock += 0.06
            return "T00\(index)"
        }
        #expect(!complete)
        #expect(inventory.mayContain("TNEW"))
        #expect(clock <= 0.12)
    }
    @Test("M6 additions cannot change established generations' safety inputs")
    func generationScope() {
        for brand in ["Apple M4 Max", "Apple M5", "Apple M60", "unknown"] {
            #expect(GenerationThermalKeys.additional(for: brand).isEmpty)
        }
        let keys = GenerationThermalKeys.additional(for: "Apple M6")
        #expect(keys.contains("Tp0j") && keys.contains("Tg1h"))
        #expect(Set(keys).count == keys.count)
        #expect(!keys.contains("Te09"))
    }

    @Test("A failed firmware enumeration falls back to fresh temperature reads")
    func firmwareFailureFailsOpen() {
        var valueReads = 0
        let smc = SMCConnection { input, output in
            output.result = 0
            if input.data8 == SMCCommand.readKeyInfo.rawValue { output.keyInfo.dataSize = 4 }
            else if input.data8 == SMCCommand.getKeyFromIndex.rawValue { output.result = 1 }
            else if input.key == 0x234B4559 { output.bytes.3 = 1 } // #KEY, one index fails
            else { valueReads += 1; output.bytes.0 = 60 }
            return kIOReturnSuccess
        }
        smc.enableInventoryCaching()
        #expect(smc.readKey("TCPU").success)
        #expect(!smc.inventoryIsComplete)
        #expect(smc.readKey("TCPU").success)
        #expect(valueReads == 2)
    }
    @Test("Unsupported inventories back off and stop retrying until invalidated")
    func boundedDiscoveryRetries() {
        var retry = SMCInventoryRetry()
        #expect(retry.canAttempt(at: 0))
        retry.failed(at: 0)
        #expect(!retry.canAttempt(at: 4))
        #expect(retry.canAttempt(at: 5))
        retry.failed(at: 5)
        #expect(!retry.canAttempt(at: 14))
        #expect(retry.canAttempt(at: 15))
        retry.failed(at: 15)
        #expect(!retry.canAttempt(at: 100_000))
        retry = SMCInventoryRetry()
        #expect(retry.canAttempt(at: 100_000))
    }
    @Test("Only complete valid enumerations can hide an absent key")
    func incompleteInventory() {
        var inventory = SMCKeyInventory()
        #expect(inventory.mayContain("TNEW"))
        let success = inventory.rebuild(count: 2) { $0 == 0 ? "TCPU" : nil }
        #expect(!success)
        #expect(inventory.mayContain("TNEW"))
        let valid = inventory.rebuild(count: 2) { $0 == 0 ? "TCPU" : "TGPU" }
        #expect(valid)
        #expect(inventory.mayContain("TCPU"))
        #expect(!inventory.mayContain("TNEW"))
        let duplicate = inventory.rebuild(count: 2) { _ in "TCPU" }
        #expect(!duplicate)
        #expect(inventory.mayContain("TNEW"))
    }

    @Test("Warm absent temperature reads skip I/O; invalidation rediscovers new keys and control reads stay fresh")
    func cachedMissingAndWake() {
        var known = ["#KEY", "TCPU", "F0Md"]
        var calls = 0
        func code(_ key: String) -> UInt32 { key.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
        let smc = SMCConnection { input, output in
            calls += 1
            output.result = 0
            if input.data8 == SMCCommand.getKeyFromIndex.rawValue {
                guard Int(input.data32) < known.count else { output.result = 1; return kIOReturnSuccess }
                output.key = code(known[Int(input.data32)])
            } else if input.data8 == SMCCommand.readKeyInfo.rawValue {
                output.keyInfo.dataSize = input.key == code("#KEY") ? 4 : 1
            } else if input.key == code("#KEY") {
                output.bytes.3 = UInt8(known.count)
            } else { output.bytes.0 = 1 }
            return kIOReturnSuccess
        }
        smc.enableInventoryCaching()
        #expect(smc.readKey("TCPU").success)
        let warm = calls
        #expect(!smc.readKey("TNEW").success)
        #expect(calls == warm)
        #expect(smc.readKey("F0Md").success)
        #expect(smc.readKey("F0Md").success)
        #expect(calls == warm + 4)
        known.append("TNEW")
        smc.invalidateInventory()
        #expect(smc.readKey("TNEW").success)
    }
}
