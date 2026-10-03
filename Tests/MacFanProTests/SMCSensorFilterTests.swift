import Foundation
import Testing
@testable import MacFanProCore

@Suite("SMC sensor filter — battery keys and die placeholders")
struct SMCSensorFilterTests {
    private let m4MaxBattery: Set<String> = ["TG0B", "TG0C", "TG0H", "TG0V", "TG1B", "TG2B"]

    @Test("Sensor acceptance distinguishes battery keys, die placeholders and cold ambient readings")
    func sensorAcceptance() {
        let cases: [(key: String, value: Float, batteryKeys: Set<String>, accepted: Bool)] = [
            ("TG0B", 27.1, m4MaxBattery, false),
            ("TG0H", 27.1, m4MaxBattery, false),
            ("TG0V", 27.1, m4MaxBattery, false),
            // Upstream verified TG0B as a GPU sensor on M5 Max, where it is not a battery key.
            ("TG0B", 61.0, [], true),
            ("Tg05", 90.0, m4MaxBattery, true),
            ("TCDX", 38.5, m4MaxBattery, true),
            ("TCMb", 45.3, m4MaxBattery, true),
            ("Tp06", 63.9, m4MaxBattery, true),
            ("Tp01", 1.5, [], false),
            ("Tp01", 1.9, [], false),
            ("Tp01", 5.2, [], false),
            ("Tp01", 40.0, [], true), // indistinguishable from a real reading
            ("Tp01", SMCSensorFilter.minimumDieTemperature, [], true),
            ("TAOL", 4.0, [], true),
            ("TB0T", 4.0, [], true),
            ("TH0x", 4.0, [], true),
            ("TN0n", 4.0, [], true),
        ]
        for row in cases {
            #expect(SMCSensorFilter.accepts(row.key, row.value, batteryKeys: row.batteryKeys) == row.accepted,
                    "\(row.key) at \(row.value)°C, battery=\(row.batteryKeys.contains(row.key))")
        }
    }

    @Test("LocationID decodes to its four-character key")
    func locationDecoding() {
        #expect(SMCSensorFilter.fourCharKey(1_413_951_555) == "TG0C")
        #expect(SMCSensorFilter.fourCharKey(1_414_410_350) == "TN0n")
        #expect(SMCSensorFilter.fourCharKey(0) == nil)
    }

    @Test("On this Mac the HID lookup agrees with the recorded battery keys", .enabled(if: isMac16_5))
    func liveBatteryLookup() {
        #expect(Set(["TG0B", "TG0H", "TG0V"]).isSubset(of: SMCSensorFilter.batteryKeys))
    }
}

private var isMac16_5: Bool {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model) == "Mac16,5"
}
