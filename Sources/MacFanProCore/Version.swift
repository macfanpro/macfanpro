//
//  Version.swift
//  MacFanPro
//
//  Single source of truth for the MacFanPro version. Referenced by the CLI
//  `--version`, the logged session metadata, the daemon's `version` command,
//  and the CLI's daemon-version reconciliation check — so all four can never
//  drift apart within a build.
//

public enum MacFanProVersion {
    /// Change the base only after integrating the corresponding upstream release.
    public static let upstream = "0.2.3"
    public static let revision = 54
    public static let current = "\(upstream).\(revision)"

    /// Strict dotted-numeric release ordering, with no version-specific exceptions.
    public static func isNewerRelease(_ candidate: String, than installed: String) -> Bool {
        func valid(_ version: String) -> Bool {
            let parts = version.split(separator: ".", omittingEmptySubsequences: false)
            return (3...4).contains(parts.count) && parts.allSatisfy { part in
                !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) } && Int(part) != nil
            }
        }
        guard valid(candidate), valid(installed) else { return false }
        return !atLeast(installed, candidate)
    }

    /// Daemons at or above this version understand the fan-command protocol
    /// additions from 0.1.5: the `oneshot` token (unsupervised holds that don't
    /// arm the heartbeat watchdog) and per-fan `setfan`. Older daemons silently
    /// ignore the token (a hold reverts after ~15s) and reject `setfan`, so the
    /// CLI checks the daemon's reported version against this before routing and
    /// warns rather than diverging silently.
    public static let oneshotProtocolSince = "0.1.5"

    /// True if dotted-numeric `version` >= `minimum` (e.g. "0.1.5" >= "0.1.4").
    public static func atLeast(_ version: String, _ minimum: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
        let a = parts(version), b = parts(minimum)
        for i in 0..<Swift.max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return true
    }

    /// Minimum macOS version, as written into the app bundle's Info.plist
    /// (LSMinimumSystemVersion) by `build-app`. Kept here so the assembler has
    /// no hardcoded field.
    ///
    /// This is the SAME floor as two build/packaging manifests that cannot
    /// import this constant and so must be kept in sync by hand:
    ///   - Package.swift          → `.macOS(.v14)`  (SPM manifest, evaluated
    ///                              standalone before this module is built)
    ///   - Homebrew formula       → `depends_on macos: :sonoma`  (Ruby, tap repo)
    /// All three currently mean macOS 14 (Sonoma).
    public static let minimumMacOS = "14.0"
}
