import Foundation

/// Invalid input must never become an indefinite recording or trap during formatting.
public enum CaptureDuration {
    public static func isValid(_ seconds: TimeInterval) -> Bool {
        seconds.isFinite && seconds > 0 && Int(exactly: seconds.rounded(.towardZero)) != nil
    }

    public static func parse(_ text: String) -> TimeInterval? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let multiplier: Double
        let number: String
        switch value.last {
        case "h": multiplier = 3600; number = String(value.dropLast())
        case "m": multiplier = 60; number = String(value.dropLast())
        case "s": multiplier = 1; number = String(value.dropLast())
        default: multiplier = 1; number = value
        }
        guard let parsed = Double(number) else { return nil }
        let seconds = parsed * multiplier
        return isValid(seconds) ? seconds : nil
    }
}
