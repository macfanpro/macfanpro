import Darwin
import Foundation

/// A separate process prevents the test runner's inherited signal disposition
/// from hiding a fatal SIGPIPE. Uses the production server without SMC access.
@main
struct DisconnectedClients {
    static func main() throws {
        signal(SIGPIPE, SIG_DFL)
        try daemonSurvivesVanishedClients()
        try clientSurvivesVanishedDaemon()
    }

    static func daemonSurvivesVanishedClients() throws {
        let path = "/tmp/tfp-disconnect-\(UUID().uuidString).sock"

        func address() -> sockaddr_un {
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 104) {
                    _ = strlcpy($0, path, 104)
                }
            }
            return addr
        }

        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = address()
        let result = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        precondition(result == 0 && listen(listener, 16) == 0)
        defer { close(listener); unlink(path) }

        let server = ConnectionServer(listenFD: listener, authorizer: PeerAuthorizer(ownerUID: getuid())) { _ in
            Thread.sleep(forTimeInterval: 0.02)
            return .statusResponse(String(repeating: "A", count: 12000))
        }

        func client() -> Int32 {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            var one: Int32 = 1
            precondition(setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one,
                                   socklen_t(MemoryLayout<Int32>.size)) == 0)
            var timeout = timeval(tv_sec: 3, tv_usec: 0)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout,
                       socklen_t(MemoryLayout<timeval>.size))
            var addr = address()
            let result = withUnsafePointer(to: &addr) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            precondition(result == 0, "connect failed: \(errno)")
            return fd
        }

        func abandonReply() throws {
            let fd = client()
            defer { close(fd) }
            try DaemonProtocol.writeFrame(fd, DaemonProtocol.encodeFrame(
                DaemonRequest(verb: .status), max: DaemonProtocol.maxRequestBytes
            ))
        }

        // Already-closed peers are queued before any socket options can be set.
        for _ in 0..<8 { try abandonReply() }
        server.start()
        for _ in 0..<100 {
            try abandonReply()
            Thread.sleep(forTimeInterval: 0.03)
        }

        let next = client()
        defer { close(next) }
        try DaemonProtocol.writeFrame(next, DaemonProtocol.encodeFrame(
            DaemonRequest(verb: .version), max: DaemonProtocol.maxRequestBytes
        ))
        let response = try DaemonProtocol.decode(DaemonResponse.self, from:
            DaemonProtocol.readFrame(next, max: DaemonProtocol.maxResponseBytes))
        precondition(response.ok)
        print("PASS: 108 abandoned replies and a subsequent request with default SIGPIPE disposition")
    }

    /// Upstream's client-side scenario, run here with fatal SIGPIPE enabled rather
    /// than changing the signal handler of the shared Swift Testing process.
    static func clientSurvivesVanishedDaemon() throws {
        let path = "/tmp/mfp-vanished-daemon-\(UUID().uuidString).sock"
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        precondition(listener >= 0)
        defer { close(listener); unlink(path) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 104) {
                _ = strlcpy($0, path, 104)
            }
        }
        let result = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        precondition(result == 0 && listen(listener, 16) == 0)

        let rounds = 300
        let finished = DispatchGroup()
        finished.enter()
        let acceptor = Thread {
            defer { finished.leave() }
            for _ in 0..<rounds {
                let fd = accept(listener, nil, nil)
                precondition(fd >= 0, "accept failed: \(errno)")
                close(fd)
            }
        }
        acceptor.start()
        let client = DaemonClient(socketPath: path)
        var failures = 0
        for _ in 0..<rounds {
            do { _ = try client.request(DaemonRequest(verb: .version), timeout: 1) }
            catch { failures += 1 }
        }
        precondition(failures == rounds, "A vanished daemon must never produce a successful reply")
        precondition(finished.wait(timeout: .now() + 5) == .success)
        print("PASS: 300 vanished-daemon requests failed cleanly with default SIGPIPE disposition")
    }
}
