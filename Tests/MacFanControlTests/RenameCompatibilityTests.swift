import Foundation
import Testing
@testable import MacFanControlCore

@Suite("Rename compatibility — temporary files only")
struct RenameCompatibilityTests {
    @Test("Old app becomes an alias; repeat upgrades work and failures preserve it")
    func aliases() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let app = root.appendingPathComponent("MacFanControl.app")
        let old = root.appendingPathComponent("MacFanPro.app")
        let cli = root.appendingPathComponent("macfancontrol")
        let service = root.appendingPathComponent("macfanpro")
        try fm.createDirectory(at: app, withIntermediateDirectories: true)
        try fm.createDirectory(at: old.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let info = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "io.github.macfanpro.app"], format: .xml, options: 0)
        try info.write(to: old.appendingPathComponent("Contents/Info.plist"))
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: service)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: service.path)
        #expect(throws: CocoaError.self) {
            try RenameCompatibility.finish(app: app, oldApp: old, command: cli, service: service,
                                           hide: { _ in throw CocoaError(.fileWriteUnknown) })
        }
        #expect(fm.fileExists(atPath: old.appendingPathComponent("Contents/Info.plist").path))
        for _ in 0..<2 {
            try RenameCompatibility.finish(app: app, oldApp: old, command: cli, service: service)
            #expect(old.resolvingSymlinksInPath() == app.resolvingSymlinksInPath())
            #expect(cli.resolvingSymlinksInPath() == service.resolvingSymlinksInPath())
        }
        try fm.removeItem(at: old)
        try fm.createDirectory(at: old, withIntermediateDirectories: true)
        #expect(throws: CocoaError.self) {
            try RenameCompatibility.finish(app: app, oldApp: old, command: cli, service: service)
        }
        #expect(fm.fileExists(atPath: old.path))
    }
}
