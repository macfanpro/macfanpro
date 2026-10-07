import Foundation

/// The installer prepares and validates the app before entering this sequence.
/// Stop failures leave files intact. Every subsequent failure restores the old
/// service files; a failed recovery is surfaced alongside the original error.
public enum ServiceLifecycle {
    public struct RecoveryFailure: Error, LocalizedError {
        public let original: Error
        public let recovery: Error
        public var errorDescription: String? {
            "Installation failed: \(original.localizedDescription). Service recovery also failed: \(recovery.localizedDescription)"
        }
    }

    public static func install(stop: () throws -> Void,
                               replaceFiles: () throws -> Void,
                               start: () throws -> Void,
                               verify: () throws -> Void,
                               commitApp: () throws -> Void,
                               recover: () throws -> Void) throws {
        // If launchd could not confirm the old job stopped, do not touch files or
        // restart it speculatively. The caller still owns an untouched app stage.
        try stop()
        do {
            try replaceFiles()
            try start()
            try verify()
            try commitApp()
        } catch {
            let original = error
            do { try recover() }
            catch { throw RecoveryFailure(original: original, recovery: error) }
            throw original
        }
    }

    /// Explicit uninstall stops the writer before resetting fans. A stop/reset
    /// failure must retain the files needed to retry, rather than orphan a job.
    public static func uninstall(stop: () throws -> Void,
                                 resetFans: () throws -> Void,
                                 removeFiles: () throws -> Void) throws {
        try stop()
        try resetFans()
        try removeFiles()
    }
}
