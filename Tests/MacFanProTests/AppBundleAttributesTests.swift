import Darwin
import Foundation
import Testing
@testable import MacFanProCore

@Suite("Installed bundle attributes")
struct AppBundleAttributesTests {
    private let key = "com.macfanpro.fixture"

    private func setAttribute(at url: URL) throws {
        let value = Array("keep-outside".utf8)
        let result = value.withUnsafeBytes {
            setxattr(url.path, key, $0.baseAddress, $0.count, 0, 0)
        }
        try #require(result == 0, "fixture setxattr failed: \(errno)")
    }

    private func attribute(at url: URL) -> String? {
        var bytes = [UInt8](repeating: 0, count: 64)
        let count = getxattr(url.path, key, &bytes, bytes.count, 0, 0)
        guard count >= 0 else { return nil }
        return String(decoding: bytes.prefix(count), as: UTF8.self)
    }

    @Test("Cleanup reaches bundle children but preserves targets outside the bundle")
    func symlinkBoundary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mfp-attributes-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent("App with spaces.app")
        let contents = bundle.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let inside = contents.appendingPathComponent("inside.txt")
        let outside = root.appendingPathComponent("outside.txt")
        for file in [inside, outside] { try Data("fixture".utf8).write(to: file) }
        for file in [bundle, inside, outside] { try setAttribute(at: file) }
        try FileManager.default.createSymbolicLink(at: contents.appendingPathComponent("external"),
                                                  withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: contents.appendingPathComponent("missing"),
                                                  withDestinationURL: root.appendingPathComponent("absent"))

        try AppBundleAttributes.clear(in: bundle)

        #expect(attribute(at: bundle) == nil)
        #expect(attribute(at: inside) == nil)
        #expect(attribute(at: outside) == "keep-outside")
        #expect(try String(contentsOf: outside, encoding: .utf8) == "fixture")
    }

    @Test("An unsuccessful system cleanup throws instead of reporting success")
    func missingBundleFails() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-mfp-\(UUID()).app")
        #expect(throws: AppBundleAttributes.CleanupError.self) { try AppBundleAttributes.clear(in: missing) }
    }
}
