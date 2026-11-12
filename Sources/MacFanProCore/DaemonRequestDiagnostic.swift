import Foundation

/// Format typed, processed results rather than raw socket bytes. Explicit CLI speed
/// commands must retain their accepted targets even when low-level ramp logs are quiet.
enum DaemonRequestDiagnostic {
    static func message(request: DaemonRequest, response: DaemonResponse) -> String {
        var message = "MacFanPro daemon: verb=\(request.verb.rawValue) outcome=\(response.ok ? "ok" : (response.error?.rawValue ?? "error"))"
        guard response.ok, request.oneshot,
              request.verb == .set || request.verb == .setfan else { return message }
        if let fan = request.fan, request.verb == .setfan { message += " requestedFan=\(fan)" }
        if let rpm = request.rpm { message += " requestedRPM=\(rpm)" }
        if let targets = response.appliedFanRPMs {
            let details = targets.map { "fan \($0.index)=\($0.rpm) RPM" }.joined(separator: ", ")
            // A thermal override can queue these targets rather than writing them now.
            message += " acceptedTargets=[\(details)]"
        }
        if let note = response.note { message += " note=\(note)" }
        return message
    }
}
