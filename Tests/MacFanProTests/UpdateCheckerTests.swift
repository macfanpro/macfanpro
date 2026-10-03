//
//  UpdateCheckerTests.swift
//  MacFanPro
//
//  Pure comparison logic for the update check. The network fetch isn't exercised
//  here — evaluate() is the part with the edge cases (the "v" strip, numeric vs
//  lexical compare, malformed tags never yielding a false positive).
//

import Foundation
import Testing
@testable import MacFanProCore

struct UpdateCheckerTests {
    private let url = "https://example.com/r"

    @Test("New releases preserve metadata and normalize the optional v prefix")
    func releaseMetadata() {
        for tag in ["v0.3.0", "0.3.0"] {
            #expect(UpdateChecker.evaluate(current: "0.2.0", tagName: tag, url: url)
                    == AvailableUpdate(version: "0.3.0", url: url), "Tag: \(tag)")
        }
    }

    @Test("Numeric ordering covers component boundaries, rollback and equivalent versions")
    func numericOrder() {
        // Compare adjacent releases at each boundary instead of a Cartesian product.
        // Explicit rollover pairs ensure a larger lower component cannot win.
        let ordered = ["0.2.3.8", "0.2.3.9", "0.2.3.10", "0.2.4", "0.2.4.1",
                       "0.3.0", "0.3.0.1", "0.3.1", "0.3.2", "0.3.3", "0.3.4", "1.0.0"]
        let pairs = Array(zip(ordered, ordered.dropFirst())) + [
            ("0.2.9", "0.2.10"), ("0.2.3.99", "0.2.4.1"), ("0.2.4.9", "0.3.0.1"),
        ]
        for (older, newer) in pairs {
            #expect(UpdateChecker.evaluate(current: older, tagName: "v\(newer)", url: url)?.version == newer,
                    "Upgrade: \(older) -> \(newer)")
            #expect(UpdateChecker.evaluate(current: newer, tagName: "v\(older)", url: url) == nil,
                    "Downgrade: \(newer) -> \(older)")
        }
        for version in ordered {
            #expect(UpdateChecker.evaluate(current: version, tagName: "v\(version)", url: url) == nil,
                    "Equal: \(version)")
        }
        for version in ["0.2.3", "0.3.3", "1.0.0"] {
            #expect(UpdateChecker.evaluate(current: version, tagName: "v\(version).0", url: url) == nil,
                    "Implicit zero: \(version)")
            #expect(UpdateChecker.evaluate(current: "\(version).0", tagName: "v\(version)", url: url) == nil,
                    "Explicit zero: \(version).0")
        }
    }

    @Test("Malformed or empty tags never yield a false update")
    func malformed() {
        for tag in ["vX.Y", "", "v", "v99.bad.1", "v0.2.3.", "v0..2.3", "v0.2.3.-1",
                    "v0.2.3-pro.9", "v0.2.3.999999999999999999999"] {
            #expect(UpdateChecker.evaluate(current: "0.2.3.9", tagName: tag, url: url) == nil,
                    "Malformed tag: \(tag)")
        }
    }

    @Test("Release numbering does not change protocol capability comparison")
    func protocolOrderUnchanged() {
        #expect(MacFanProVersion.atLeast("0.2.3.9", MacFanProVersion.oneshotProtocolSince))
        #expect(!MacFanProVersion.atLeast("0.1.4", MacFanProVersion.oneshotProtocolSince))
        #expect(!MacFanProVersion.atLeast("0.2.3.9", "0.3.3"))
        #expect(!MacFanProVersion.isNewerRelease("0.2.3.9", than: "0.3.3"))
    }

    @Test("The latest-release redirect yields the tag, or nothing newer, or a failure")
    func latestTagFromRedirect() {
        func landed(_ url: String) -> String?? { UpdateChecker.latestTag(fromFinalURL: URL(string: url)!) }
        #expect(landed("https://github.com/macfanpro/macfanpro/releases/tag/v0.2.3.24") == .some("v0.2.3.24"))
        // No release yet: GitHub shows the release list; nothing is newer.
        #expect(landed("https://github.com/macfanpro/macfanpro/releases") == .some(nil))
        // Anything else is not an answer: a login wall, a portal, another repo or host.
        for other in ["https://github.com/login?return_to=%2Fmacfanpro",
                      "https://portal.example.com/macfanpro/macfanpro/releases/tag/v9.9.9",
                      "http://github.com/macfanpro/macfanpro/releases/tag/v9.9.9",
                      "https://github.com/someone/else/releases/tag/v9.9.9",
                      "https://github.com/macfanpro/macfanpro/releases/tag/",
                      "https://github.com/macfanpro/macfanpro/releases/tag/v1/extra"] {
            #expect(landed(other) == nil)
        }
    }
}
