import Foundation

/// Only durable user choices cross the product migration boundary. Cached release
/// information belongs to its original update channel.
public enum LegacyPreferences {
    public static func merging(old: [String: Any], current: [String: Any]) -> [String: Any] {
        var result = current
        for key in ["guiLanguage", "useFahrenheit", "selectedProfile"] where result[key] == nil {
            result[key] = old[key]
        }
        return result
    }
}
