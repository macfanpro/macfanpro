//
//  UpdateScript.swift
//  MacFanPro
//
//  "Update in Terminal": writes the update steps for this install to a .command
//  file and opens it in Terminal, so the user only enters their password once.
//  The steps stay visible in Terminal; nothing runs without the user watching.
//

import AppKit
import MacFanProCore

enum UpdateScript {
    /// Terminal's curl and Homebrew ignore the macOS proxy settings, so networks
    /// that need a proxy for GitHub would fail. Use the system HTTPS proxy unless
    /// the user already set one.
    private static let proxySetup = """
        if [ -z "${https_proxy:-}${HTTPS_PROXY:-}${all_proxy:-}${ALL_PROXY:-}" ]; then
          proxy=$(scutil --proxy | awk '/HTTPSEnable : 1/{e=1} /HTTPSProxy :/{h=$3} /HTTPSPort :/{p=$3} END{if (e && h) print "http://" h ":" p}')
          if [ -n "$proxy" ]; then export https_proxy="$proxy" http_proxy="$proxy"; echo "Using the system proxy $proxy"; fi
        fi
        """

    static func contents(version: String, homebrew: Bool) -> String {
        let steps: String
        if homebrew {
            steps = """
                BREW=/opt/homebrew/bin/brew
                [ -x "$BREW" ] || BREW=/usr/local/bin/brew
                echo "Updating MacFanPro with Homebrew…"
                "$BREW" trust macfanpro/tap 2>/dev/null || true
                "$BREW" update || true
                "$BREW" upgrade macfanpro
                CLI="$("$BREW" --prefix macfanpro)/bin/macfanpro"
                """
        } else {
            let name = "MacFanPro-\(version)-macos-arm64"
            steps = """
                BASE="https://github.com/macfanpro/macfanpro/releases/download/v\(version)"
                WORK=$(mktemp -d)
                cd "$WORK"
                echo "Downloading MacFanPro \(version)…"
                curl -fL --progress-bar -O "$BASE/\(name).tar.gz"
                curl -fsSL -O "$BASE/SHA256SUMS"
                shasum -a 256 -c SHA256SUMS
                tar -xzf "\(name).tar.gz"
                CLI="$WORK/\(name)/bin/macfanpro"
                """
        }
        return """
            #!/bin/zsh
            # MacFanPro update to \(version). Created by the MacFanPro menu bar app.
            set -e
            trap 'echo; echo "The update did not finish. See the message above, or update manually: https://github.com/macfanpro/macfanpro#updating"' ERR
            \(proxySetup)
            \(steps)
            "$CLI" auto --stop-app
            echo
            echo "Enter your Mac password to install the background service (nothing is shown while you type):"
            sudo "$CLI" install
            open /Applications/MacFanPro.app
            echo
            echo "MacFanPro is up to date. You can close this window."

            """
    }

    /// Write the script to the user's temporary folder and open it in Terminal.
    static func open(version: String, homebrew: Bool) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MacFanPro Update.command")
        do {
            try contents(version: version, homebrew: homebrew).write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        } catch {
            TFLogger.shared.error("Could not write the update script: \(error)")
            return
        }
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}
