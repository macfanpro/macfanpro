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

    @Test("a newer tag is an available update")
    func newer() {
        let u = UpdateChecker.evaluate(current: "0.2.0", tagName: "v0.2.1", url: url)
        #expect(u == AvailableUpdate(version: "0.2.1", url: url))
    }

    @Test("the leading v is stripped from the reported version")
    func stripsV() {
        let u = UpdateChecker.evaluate(current: "0.2.0", tagName: "v0.3.0", url: url)
        #expect(u?.version == "0.3.0")
        // A tag without a v works identically.
        #expect(UpdateChecker.evaluate(current: "0.2.0", tagName: "0.3.0", url: url)?.version == "0.3.0")
    }

    @Test("equal version is not an update")
    func equal() {
        #expect(UpdateChecker.evaluate(current: "0.2.1", tagName: "v0.2.1", url: url) == nil)
    }

    @Test("an older tag is not an update")
    func older() {
        #expect(UpdateChecker.evaluate(current: "0.2.1", tagName: "v0.2.0", url: url) == nil)
    }

    @Test("compare is numeric, not lexical (0.2.10 > 0.2.9)")
    func numeric() {
        #expect(UpdateChecker.evaluate(current: "0.2.9", tagName: "v0.2.10", url: url)?.version == "0.2.10")
        #expect(UpdateChecker.evaluate(current: "0.2.10", tagName: "v0.2.9", url: url) == nil)
    }

    @Test("a malformed or empty tag never yields a false update")
    func malformed() {
        // Malformed tags are rejected before release-order comparison.
        #expect(UpdateChecker.evaluate(current: "0.2.0", tagName: "vX.Y", url: url) == nil)
        #expect(UpdateChecker.evaluate(current: "0.2.0", tagName: "", url: url) == nil)
        #expect(UpdateChecker.evaluate(current: "0.2.0", tagName: "v", url: url) == nil)
        for tag in ["v99.bad.1", "v0.2.3.", "v0..2.3", "v0.2.3.-1", "v0.2.3-pro.9", "v0.2.3.999999999999999999999"] {
            #expect(UpdateChecker.evaluate(current: "0.2.3.9", tagName: tag, url: url) == nil)
        }
    }

    @Test("Three- and four-component releases share a consistent numeric order")
    func numericOrderAcrossReleaseFormats() {
        let versions = ["0.2.3.8", "0.2.3.9", "0.2.3.10", "0.2.4", "0.2.4.1",
                        "0.3.0", "0.3.0.1", "0.3.1", "0.3.2", "0.3.3", "0.3.4", "1.0.0"]
        for (i, installed) in versions.enumerated() {
            for (j, candidate) in versions.enumerated() {
                let update = UpdateChecker.evaluate(current: installed, tagName: "v\(candidate)", url: url)
                #expect(update?.version == (j > i ? candidate : nil))
            }
        }
    }

    @Test("An omitted fourth component is equivalent to zero")
    func equivalentNumericVersions() {
        for version in ["0.2.3", "0.3.3", "1.0.0"] {
            #expect(UpdateChecker.evaluate(current: version, tagName: "v\(version).0", url: url) == nil)
            #expect(UpdateChecker.evaluate(current: "\(version).0", tagName: "v\(version)", url: url) == nil)
        }
    }

    @Test("Revision and upstream-base changes preserve numeric order")
    func upstreamRevisionOrder() {
        for (older, newer) in [("0.2.3.8", "0.2.3.9"), ("0.2.3.9", "0.2.3.10"),
                               ("0.2.3.99", "0.2.4.1"), ("0.2.4.9", "0.3.0.1")] {
            #expect(UpdateChecker.evaluate(current: older, tagName: "v\(newer)", url: url)?.version == newer)
            #expect(UpdateChecker.evaluate(current: newer, tagName: "v\(older)", url: url) == nil)
        }
        #expect(UpdateChecker.evaluate(current: "0.2.3.9", tagName: "v0.2.3.9", url: url) == nil)
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
