//
//  UpdateChecker.swift
//  MacFanPro
//
//  "Is there a newer release?" check against the public GitHub releases page. The
//  app already knows its own version; this tells it when a newer one has shipped
//  so a user still on an old build finds out without happening to run
//  `brew upgrade`. It sends nothing about the user — a plain HEAD request to a
//  public page, the same request anyone loading the repo page makes.
//
//  Why the page and not the REST API: /releases/latest on github.com redirects to
//  the latest release's tag page, which is all this needs. The unauthenticated API
//  allows 60 requests an hour per IP, and proxy exit IPs shared by many users (the
//  usual way to reach GitHub from some networks) exhaust that for everyone behind
//  them. URLSession uses the system proxy settings.
//
//  Two halves, split so the comparison is unit-testable without a network:
//    - evaluate(...)  pure: given the current version + a release tag, decide.
//    - check(...)     async: follow /releases/latest and run evaluate on its tag.
//
//  The check is SILENT on every failure. It returns `.failed` (never a spurious
//  `.upToDate`) so the caller leaves any prior state untouched and never shows a
//  banner off a check that didn't actually complete — offline, rate-limited, and
//  GitHub-down all look the same and all do nothing.
//

import Foundation

/// A release strictly newer than what's installed.
public struct AvailableUpdate: Equatable, Sendable {
    /// The release version, already stripped of any leading "v" (e.g. "0.2.2").
    public let version: String
    /// The release's page URL, for a "What's new" link.
    public let url: String

    public init(version: String, url: String) {
        self.version = version
        self.url = url
    }
}

/// Outcome of an update check. Three states, not an optional, so a *failed* check
/// (leave prior state) is distinct from a *successful* "you're current" (clear any
/// stale banner). The banner shows only for `.update`.
public enum UpdateCheckResult: Equatable, Sendable {
    case upToDate
    case update(AvailableUpdate)
    case failed
}

public enum UpdateChecker {
    /// `/releases/latest` redirects to the newest release EXCLUDING drafts and
    /// prereleases, so only stable releases we actually cut can ever surface. Also
    /// the fallback "What's new" link when a persisted check has no stored URL.
    public static let releasesPageURL = "https://github.com/macfanpro/macfanpro/releases/latest"
    private static let releasesPath = "/macfanpro/macfanpro/releases"

    /// Pure comparison. Returns an AvailableUpdate iff `tagName` is a strictly newer
    /// version than `current`, else nil.
    ///
    /// Strips a single leading "v", validates numeric components and compares
    /// their values from left to right, treating omitted components as zero.
    public static func evaluate(current: String, tagName: String, url: String) -> AvailableUpdate? {
        let tag = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        guard !tag.isEmpty else { return nil }
        guard MacFanProVersion.isNewerRelease(tag, than: current) else { return nil }
        return AvailableUpdate(version: tag, url: url)
    }

    /// Where /releases/latest ended up. `.some(tag)` for a release tag page, `.some(nil)`
    /// for the release list (the repo has no release yet), nil for anything else
    /// (a login wall, a captive portal, another host).
    public static func latestTag(fromFinalURL url: URL) -> String?? {
        guard url.scheme == "https", url.host == "github.com" else { return nil }
        let path = url.path
        if path == releasesPath || path == releasesPath + "/" { return .some(nil) }
        let prefix = releasesPath + "/tag/"
        guard path.hasPrefix(prefix) else { return nil }
        let tag = String(path.dropFirst(prefix.count))
        guard !tag.isEmpty, !tag.contains("/") else { return nil }
        return .some(tag)
    }

    /// Follow /releases/latest and evaluate the tag it lands on. `.failed` on ANY
    /// error (offline, non-200, unexpected page) so the caller can stay silent; the
    /// session is injectable for tests.
    public static func check(current: String = MacFanProVersion.current,
                             session: URLSession = .shared) async -> UpdateCheckResult {
        var request = URLRequest(url: URL(string: releasesPageURL)!, timeoutInterval: 10)
        request.httpMethod = "HEAD"
        request.setValue("MacFanPro/\(current)", forHTTPHeaderField: "User-Agent")

        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let finalURL = http.url, let landed = latestTag(fromFinalURL: finalURL)
        else {
            return .failed
        }
        guard let tag = landed else { return .upToDate }

        if let update = evaluate(current: current, tagName: tag, url: finalURL.absoluteString) {
            return .update(update)
        }
        return .upToDate
    }
}
