//
//  ProfileTests.swift
//  MacFanPro
//

import Foundation
import Testing

@testable import MacFanProCore

@Suite("Profiles")
struct ProfileTests {
    @Test("Four built-ins and Smart resolve for launch; unknown selections fall back to Silent")
    func selectableResolution() {
        #expect(FanProfile.builtIn.map(\.id) == ["silent", "balanced", "performance", "max"])
        for profile in FanProfile.builtIn + [.smart] {
            #expect(FanProfile.selectable(id: profile.id) == profile)
        }
        #expect(FanProfile.selectable(id: "does-not-exist") == .silent)
        #expect(FanProfile.selectable(id: nil) == .silent)
    }

    @Test("Profile parameters, ramp rates and sustained triggers match the published presets")
    func builtInCurves() {
        #expect(FanProfile.silent.curve.handsOff)
        #expect(FanProfile.silent.name == "Silent (Apple Default)")

        for profile in [FanProfile.balanced, .performance, .max, .smart] {
            #expect(profile.curve.stopTemp == 50, "\(profile.id)")
            #expect(!profile.curve.handsOff, "\(profile.id)")
            #expect(!profile.curve.alwaysOn, "\(profile.id)")
            #expect(profile.curve.instantEngage == (profile.id == "max"), "\(profile.id)")
        }

        // Keep each preset's contract in one place, including ramp and trigger timing.
        let balanced = FanProfile.balanced.curve
        #expect(balanced.startTemp == 55)
        #expect(balanced.ceilingTemp == 70)
        #expect(balanced.maxRPMPercent == 0.60)
        #expect(balanced.curveShape == .easeIn)
        #expect(balanced.rampUpPerSec == 0.05)
        #expect(balanced.rampDownPerSec == 0.025)
        #expect(balanced.sustainedTriggerSec == 8)

        let performance = FanProfile.performance.curve
        #expect(performance.startTemp == 55)
        #expect(performance.ceilingTemp == 65)
        #expect(performance.maxRPMPercent == 0.85)
        #expect(performance.curveShape == .linear)
        #expect(performance.rampUpPerSec == 0.10)
        #expect(performance.rampDownPerSec == 0.04)
        #expect(performance.sustainedTriggerSec == 4)

        let max = FanProfile.max.curve
        #expect(max.startTemp == 65)
        #expect(max.ceilingTemp == 65)
        #expect(max.maxRPMPercent == 1)
        #expect(max.rampDownPerSec == 0.025)
        #expect(max.sustainedTriggerSec == 5)

        let smart = FanProfile.smart.curve
        #expect(smart.startTemp == 53)
        #expect(smart.ceilingTemp == 85)
        #expect(smart.maxRPMPercent == 1)
        #expect(smart.curveShape == .sCurve)
        #expect(smart.rampUpPerSec == 0.05)
        #expect(smart.rampDownPerSec == 0.025)
        #expect(smart.sustainedTriggerSec == 6)
    }

    @Test("Built-in, Smart and custom profiles preserve every field through save and load")
    func persistenceRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacFanProTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        // Distinct names prove the loader read the saved built-ins instead of
        // silently falling back to its defaults after a decoding failure.
        let profiles = (FanProfile.builtIn + [.smart]).map {
            FanProfile(id: $0.id, name: "Saved \($0.name)", curve: $0.curve)
        } + [FanProfile(
            id: "test_custom", name: "Test Custom",
            curve: .init(stopTemp: 45, startTemp: 55, ceilingTemp: 65,
                         maxRPMPercent: 0.50, curveShape: .easeOut,
                         rampUpPerSec: 0.08, sustainedTriggerSec: 3)
        )]
        for profile in profiles { try profile.save(to: directory) }
        let loaded = FanProfile.loadAll(from: directory)
        #expect(loaded.count == profiles.count)
        for profile in profiles {
            #expect(loaded.first { $0.id == profile.id } == profile, "\(profile.id)")
        }
    }

    @Test("Preset outputs cover start, ceiling, midpoint, hands-off and both hysteresis states")
    func presetOutputs() {
        let cases: [(profile: FanProfile, temp: Float, running: Bool, expected: Float?)] = [
            (.balanced, 45, false, nil),
            (.balanced, 55, false, 0),
            (.balanced, 70, true, 0.60),
            (.balanced, 62.5, true, 0.15), // ease-in midpoint: 0.5² × 0.60
            (.balanced, 52, true, 0.001), // keep at minimum inside hysteresis band
            (.balanced, 52, false, nil),
            (.balanced, 48, true, nil),
            (.performance, 65, true, 0.85),
            (.performance, 60, true, 0.425), // linear midpoint
            (.max, 45, false, nil),
            (.max, 60, false, nil),
            (.max, 60, true, 0.001),
            (.max, 65, false, 1), // instant engagement at start
            (.max, 80, true, 1),
            (.silent, 50, false, nil),
            (.silent, 70, false, nil),
        ]
        for row in cases {
            let context = "\(row.profile.id), \(row.temp)°C, running=\(row.running)"
            let actual = row.profile.curve.targetPercent(at: row.temp, fansCurrentlyRunning: row.running)
            #expect(actual == row.expected, "\(context)")
        }
    }

    @Test("Custom curves retain S-curve endpoints and distinct ease-in/ease-out responses")
    func customCurveShapes() {
        let cases: [(shape: CurveShape, temp: Float, expected: Float)] = [
            (.sCurve, 0, 0), (.sCurve, 50, 0.5), (.sCurve, 100, 1),
            (.easeOut, 25, 0.5), (.easeIn, 25, 0.0625),
        ]
        for row in cases {
            let curve = FanProfile.Curve(stopTemp: -10, startTemp: 0, ceilingTemp: 100,
                                         maxRPMPercent: 1, curveShape: row.shape)
            let context = "\(row.shape) at \(row.temp)°C"
            #expect(curve.targetPercent(at: row.temp, fansCurrentlyRunning: true) == row.expected, "\(context)")
        }
    }
}
