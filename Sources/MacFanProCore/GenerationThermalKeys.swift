import Darwin
import Foundation

/// A key existing on another generation does not prove it measures the same
/// quantity. Keep reported M6 additions out of established M1–M5 safety inputs.
enum GenerationThermalKeys {
    static let current: [String] = {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var brand = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 else { return [] }
        return additional(for: String(cString: brand))
    }()

    static func additional(for brand: String) -> [String] {
        guard brand == "Apple M6" || brand.hasPrefix("Apple M6 ") else { return [] }
        // ThermalForge #78, with core mappings cross-checked against Stats.
        // Te09 is already in the cross-generation base list.
        return [
            "Tp0E", "Tp0I", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0o", "Tp0r",
            "Tp0t", "Tp0u", "Tp0w", "Tp0x", "Tp0y", "Tp0z",
            "Te07", "Te08", "Te0c", "Te0e", "Te0f", "Te0g", "Te0h", "Te0i",
            "Tg01", "Tg07", "Tg08", "Tg09", "Tg0a", "Tg0b", "Tg0c", "Tg0d",
            "Tg10", "Tg17", "Tg1a", "Tg1b", "Tg1c", "Tg1d", "Tg1e", "Tg1f", "Tg1g", "Tg1h",
        ]
    }
}
