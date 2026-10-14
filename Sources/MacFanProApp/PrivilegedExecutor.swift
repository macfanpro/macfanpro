//
//  PrivilegedExecutor.swift
//  MacFanPro
//
//  Sends fan commands to the privileged daemon via Unix socket.
//  No password prompts — the daemon runs as root via launchd.
//

import Foundation
import MacFanProCore

final class PrivilegedExecutor: @unchecked Sendable {
    private let client = DaemonClient()

    func execute(_ command: FanCommand) throws {
        try client.execute(command)
    }

    var isDaemonRunning: Bool {
        MacFanProDaemon.isRunning
    }
}
