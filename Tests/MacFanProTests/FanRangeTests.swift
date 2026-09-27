import Foundation
import IOKit
import Testing
@testable import MacFanProCore

@Suite("Per-fan ranges — simulated SMC, no hardware")
struct FanRangeTests {
    /// A dictionary-backed SMC: keys that exist answer reads and writes.
    final class FakeSMC: @unchecked Sendable {
        var keys: [String: [UInt8]]
        init(_ keys: [String: [UInt8]]) { self.keys = keys }

        lazy var connection = SMCConnection { [unowned self] input, output in
            let name = String(decoding: (0..<4).map { UInt8((input.key >> (24 - 8 * $0)) & 0xFF) }, as: UTF8.self)
            guard let value = self.keys[name] else {
                output.result = 0x84 // key not found
                return kIOReturnSuccess
            }
            output.result = 0
            switch input.data8 {
            case SMCCommand.readKeyInfo.rawValue:
                output.keyInfo.dataSize = UInt32(value.count)
            case SMCCommand.readBytes.rawValue:
                withUnsafeMutableBytes(of: &output.bytes) { buffer in
                    for (i, byte) in value.enumerated() { buffer[i] = byte }
                }
            case SMCCommand.writeBytes.rawValue:
                self.keys[name] = withUnsafeBytes(of: input.bytes) { Array($0.prefix(value.count)) }
            default:
                break
            }
            return kIOReturnSuccess
        }

        func float(_ key: String) -> Float { smcBytesToFloat(keys[key] ?? [], size: 4) }
    }

    @Test("Setting all fans keeps each target inside that fan's own range")
    func perFanClamp() throws {
        let smc = FakeSMC([
            "FNum": [2],
            "F0Mn": floatToSMCBytes(1350), "F0Mx": floatToSMCBytes(6000),
            "F1Mn": floatToSMCBytes(1350), "F1Mx": floatToSMCBytes(4000),
            "F0Ac": floatToSMCBytes(0), "F1Ac": floatToSMCBytes(0),
            "F0Tg": floatToSMCBytes(0), "F1Tg": floatToSMCBytes(0),
            "F0Md": [0], "F1Md": [0],
        ])
        let fans = FanControl(smc: smc.connection)
        let targets = try fans.setAllFans(rpm: 5000)
        #expect(targets == [FanRPM(index: 0, rpm: 5000), FanRPM(index: 1, rpm: 4000)])
        #expect(smc.float("F0Tg") == 5000)
        #expect(smc.float("F1Tg") == 4000)
        #expect(smc.keys["F0Md"] == [1] && smc.keys["F1Md"] == [1])
    }
}
