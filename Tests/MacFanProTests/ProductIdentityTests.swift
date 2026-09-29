import Testing
@testable import MacFanProCore
import MacFanProLocalization

@Suite("Independent product and migration boundaries")
struct ProductIdentityTests {
    @Test("Updates, IPC and resources use only the MacFanPro identity")
    func independentIdentity() {
        #expect(UpdateChecker.releasesPageURL == "https://github.com/macfanpro/macfanpro/releases/latest")
        #expect(MacFanProDaemon.socketPath == "/var/run/macfanpro.sock")
        #expect(MacFanProDaemon.label == "io.github.macfanpro.daemon")
        #expect(MacFanProDaemon.installPath == "/usr/local/bin/macfanpro")
        #expect(LocalizationCatalog.resourceBundleName == "MacFanPro_MacFanProLocalization.bundle")
    }

    @Test("Migration preserves choices without carrying the upstream update cache")
    func migratePreferences() {
        let old: [String: Any] = ["guiLanguage": "zh-Hant", "useFahrenheit": true,
                                  "selectedProfile": "smart", "updateLatestURL": "https://example.com/old",
                                  "updateLatestVersion": "99.0.0", "updateDismissedVersion": "99.0.0"]
        let result = LegacyPreferences.merging(old: old, current: [:])
        #expect(result.count == 3)
        #expect(result["guiLanguage"] as? String == "zh-Hant")
        #expect(result["useFahrenheit"] as? Bool == true)
        #expect(result["selectedProfile"] as? String == "smart")
        #expect(old.count == 6)
    }

    @Test("Existing MacFanPro preferences win over legacy choices")
    func keepCurrentPreferences() {
        let result = LegacyPreferences.merging(old: ["guiLanguage": "zh-Hant", "selectedProfile": "smart"],
                                              current: ["guiLanguage": "en", "selectedProfile": "balanced", "extra": "keep"])
        #expect(result["guiLanguage"] as? String == "en")
        #expect(result["selectedProfile"] as? String == "balanced")
        #expect(result["extra"] as? String == "keep")
    }
}
