//
//  SMCSensorFilter.swift
//  MacFanPro
//
//  Rejects SMC temperature readings that are not what their key prefix claims.
//
//  Kept in its own file so the upstream sweep in FanControl stays untouched
//  apart from one guard in `readTemp`, which both `status()` and the daemon's
//  safety floor go through. See docs/thermal-sensor-calibration-20260924.md.
//

import Foundation

enum SMCSensorFilter {

    /// CPU/GPU die sensor prefixes (upstream's four plus the `Te*` efficiency cores).
    private static let dieSensorPrefixes = ["TC", "Tp", "Te", "TG", "Tg"]

    /// A die sensor on a running Mac cannot sit below this. The `Tp*` keys
    /// intermittently hold placeholder values (1.5, 1.9 and 5.2 observed on
    /// M4 Max); under the rows' maximum they never win, but they reach the JSON
    /// status, the thermal log and any Mac exposing only those keys.
    /// A constant 40.0 placeholder also occurs and is deliberately kept: it is
    /// indistinguishable from a real 40.0°C reading.
    static let minimumDieTemperature: Float = 10

    /// SMC keys this Mac publishes as battery sensors. On Mac16,5 (M4 Max)
    /// `TG0B`, `TG0H` and `TG0V` — grouped as GPU upstream, and recorded there
    /// as M5 Max GPU keys — are the battery gas gauge. SMC metadata cannot tell
    /// the two apart (both are `ioft`, 8 bytes), so this asks the machine: the
    /// IOHIDEventSystem temperature services carry a `LocationID` that decodes
    /// to the same four-character key, and their product name says what the
    /// sensor is. Resolved once per process; empty when the lookup fails, which
    /// leaves upstream behaviour unchanged.
    static let batteryKeys: Set<String> = hidSensorKeys { $0.localizedCaseInsensitiveContains("battery") }

    static func accepts(_ key: String, _ temperature: Float,
                        batteryKeys: Set<String> = SMCSensorFilter.batteryKeys) -> Bool {
        if batteryKeys.contains(key) { return false }
        if temperature < minimumDieTemperature, dieSensorPrefixes.contains(where: { key.hasPrefix($0) }) {
            return false
        }
        return true
    }

    // MARK: - IOHID Lookup

    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatchingFn = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias CopyServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyPropertyFn = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?

    /// Four-character keys of the HID temperature services whose product name
    /// matches. Symbols are resolved with dlsym so there is no link-time
    /// dependency on private API; any failure yields an empty set.
    static func hidSensorKeys(where matches: (String) -> Bool) -> Set<String> {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return [] }
        func symbol<T>(_ name: String) -> T? { dlsym(handle, name).map { unsafeBitCast($0, to: T.self) } }
        guard let create: CreateFn = symbol("IOHIDEventSystemClientCreate"),
              let setMatching: SetMatchingFn = symbol("IOHIDEventSystemClientSetMatching"),
              let copyServices: CopyServicesFn = symbol("IOHIDEventSystemClientCopyServices"),
              let copyProperty: CopyPropertyFn = symbol("IOHIDServiceClientCopyProperty"),
              let client = create(kCFAllocatorDefault)?.takeRetainedValue()
        else { return [] }
        // Page 0xff00 / usage 5 is the temperature sensor collection.
        setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        guard let services = copyServices(client)?.takeRetainedValue() as? [AnyObject] else { return [] }

        var keys = Set<String>()
        for service in services {
            guard let product = copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String,
                  matches(product),
                  let location = (copyProperty(service, "LocationID" as CFString)?
                      .takeRetainedValue() as? NSNumber)?.uint32Value,
                  let key = fourCharKey(location)
            else { continue }
            keys.insert(key)
        }
        return keys
    }

    /// Render a LocationID as its four-character sensor key, or nil if it is
    /// not four printable ASCII characters.
    static func fourCharKey(_ value: UInt32) -> String? {
        let bytes = withUnsafeBytes(of: value.bigEndian) { Array($0) }
        guard bytes.allSatisfy({ (0x20...0x7e).contains($0) }) else { return nil }
        return String(bytes: bytes, encoding: .ascii)
    }
}
