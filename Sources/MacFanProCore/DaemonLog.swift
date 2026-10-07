//
//  DaemonLog.swift
//  MacFanPro
//
//  The daemon's unified-log channel, from ThermalForge #31. Since the 26 SDKs,
//  NSLog's dynamic data is recorded as <private>, which hid every daemon
//  diagnostic: the socket path, verbs, temperatures, errno values. Everything here
//  is logged public — nothing the daemon logs needs hiding from the Mac's own admin.
//  MacFanPro's bounded runtime log files (TFLogger) are kept alongside it.
//

import os

enum DaemonLog {
    static let subsystem = "io.github.macfanpro.daemon"
    private static let logger = Logger(subsystem: subsystem, category: "daemon")

    static func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
