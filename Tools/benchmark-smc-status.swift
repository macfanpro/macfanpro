// Read-only diagnostic, never part of the test suite. No daemon, fan writes,
// runtime logger or calibration files. Build against a Debug core with -enable-testing:
// swiftc -I .build/debug Tools/benchmark-smc-status.swift .build/debug/MacFanProCore.o \
//   -framework IOKit -framework Metal -o dist/benchmark-smc-status
import Foundation
import Darwin
@testable import MacFanProCore

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("Benchmark failed: " + message + "\n").utf8))
    exit(1)
}

do {
for round in 0..<3 {
    for cached in (round % 2 == 0 ? [false, true] : [true, false]) {
        guard let smc = SMCConnection() else { fail("AppleSMC unavailable") }
        let fans = FanControl(smc: smc, logger: nil)
        print("inventory_key_count=\(smc.getKeyCount()) first_key=\(smc.getKeyAtIndex(0) ?? "nil")")
        if cached { smc.enableInventoryCaching() }
        let coldStart = ProcessInfo.processInfo.systemUptime
        let cold = try fans.status()
        guard !cached || smc.inventoryIsComplete else {
            print("FAIL: firmware inventory is incomplete; no performance claim can be made")
            exit(1)
        }
        let coldMS = (ProcessInfo.processInfo.systemUptime - coldStart) * 1000
        for _ in 0..<5 { _ = try fans.status() }
        // Core power gating changes valid temperature values. Verify firmware
        // presence separately from status()'s value-range/battery filtering.
        guard let direct = SMCConnection() else { fail("AppleSMC unavailable during verification") }
        var checked = 0
        for key in FanControl.thermalKeys {
            let raw = direct.readKey(key)
            if raw.success {
                guard smc.readKey(key).success else { fail("Readable key hidden: " + key) }
                checked += 1
            }
        }
        var observed = Set(cold.temperatures.keys)
        var elapsed: [Double] = []
        for _ in 0..<100 {
            let start = ProcessInfo.processInfo.systemUptime
            let status = try fans.status()
            guard status.fans.count == cold.fans.count else { fail("Fan count changed") }
            observed.formUnion(status.temperatures.keys)
            elapsed.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
        }
        let sorted = elapsed.sorted()
        print("round=\(round + 1) cache=\(cached) sensors=\(observed.count) raw_keys=\(checked) fans=\(cold.fans.count) cold_ms=\(coldMS) mean_ms=\(elapsed.reduce(0,+)/Double(elapsed.count)) median_ms=\(sorted[50]) p95_ms=\(sorted[95])")
    }
}

} catch { fail(String(describing: error)) }
