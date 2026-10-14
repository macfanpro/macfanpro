import Foundation
import IOKit
import Testing
@testable import MacFanProCore

@Suite("Fan input validation without hardware")
struct FanInputValidationTests {
    @Test("Malformed SMC keys fail without making an IOKit call")
    func malformedKeys() {
        var calls = 0
        let smc = SMCConnection { _, _ in
            calls += 1
            return kIOReturnSuccess
        }
        for key in ["", "F0", "F99Ac", "F-1Md", "风扇温度", String(repeating: "F", count: 1000)] {
            #expect(!smc.readKey(key).success)
            #expect(!smc.writeKey(key, bytes: [1]))
            #expect(smc.getKeyInfo(key) == nil)
        }
        #expect(calls == 0)
    }

    @Test("Invalid fan indices never read a fan key or write hardware")
    func invalidIndices() throws {
        for count: UInt8 in [0, 2] {
            var keys: [UInt32] = []
            let smc = SMCConnection { input, output in
                keys.append(input.key)
                #expect(input.data8 != SMCCommand.writeBytes.rawValue)
                output.keyInfo.dataSize = 1
                output.bytes.0 = count
                return kIOReturnSuccess
            }
            let control = FanControl(smc: smc)
            keys.removeAll() // Hardware detection is independent of the request.
            for index in [Int.min, -1, Int(count), 9, 10, 99, Int.max] {
                do {
                    try control.setSpeed(fan: index, rpm: 3000)
                    Issue.record("Invalid fan index was accepted: \(index)")
                } catch MacFanProError.invalidFanIndex(let rejected, let detected) {
                    #expect(rejected == index && detected == Int(count))
                }
                #expect(throws: MacFanProError.self) { try control.fanInfo(index) }
            }
            #expect(!keys.isEmpty)
            #expect(keys.allSatisfy { $0 == 0x464E756D }) // FNum only.
        }
    }

    @Test("Valid last fan still receives the requested RPM")
    func validFanWrite() throws {
        var writes: [(UInt32, [UInt8])] = []
        let smc = SMCConnection { input, output in
            output.keyInfo.dataSize = input.key == 0x464E756D || input.key == 0x46316D64 ? 1 : 4
            if input.data8 == SMCCommand.readBytes.rawValue {
                output.bytes.0 = input.key == 0x464E756D ? 2 : (input.key == 0x46316D64 ? 1 : 0)
            }
            if input.data8 == SMCCommand.writeBytes.rawValue {
                writes.append((input.key, withUnsafeBytes(of: input.bytes) { Array($0.prefix(4)) }))
            }
            return kIOReturnSuccess
        }
        try FanControl(smc: smc).setSpeed(fan: 1, rpm: 3000.5)
        #expect(writes.count == 1)
        #expect(writes.first?.0 == 0x46315467) // F1Tg
        #expect(writes.first?.1 == floatToSMCBytes(3000.5))
    }

    @Test("Extreme RPM values are rejected before hardware access")
    func invalidRPM() throws {
        var calls = 0
        let smc = SMCConnection { _, output in
            calls += 1
            output.keyInfo.dataSize = 1
            return kIOReturnSuccess
        }
        let control = FanControl(smc: smc)
        calls = 0
        for rpm: Float in [-1, Float(Int.min), Float(Int.max), .infinity, -.infinity, .nan] {
            #expect(throws: MacFanProError.self) { try control.setSpeed(fan: 0, rpm: rpm) }
            #expect(throws: MacFanProError.self) { try control.setAllFans(rpm: rpm) }
        }
        #expect(calls == 0)
        for rpm: Float in [0, 3000, 3000.5, 999999] { try FanControl.validateRPM(rpm) }
    }

    @Test("Unrepresentable client RPMs produce invalid requests instead of trapping")
    func invalidWireRPM() {
        for rpm: Float in [Float(Int.max), .infinity, -.infinity, .nan] {
            #expect(DaemonRequest(.setRPM(rpm), oneshot: true).rpm == nil)
            #expect(DaemonRequest(.setFan(index: 1, rpm: rpm), oneshot: true).rpm == nil)
        }
        #expect(DaemonRequest(.setRPM(3000.5), oneshot: true).rpm == 3000)
    }
}
