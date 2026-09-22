#if canImport(Network)
import Foundation
import Network

/// A minimal HTTP/1.1 server bound to `127.0.0.1` on an ephemeral port, for tests that need a real
/// socket rather than a mocked `HTTPClient`.
///
/// It exists so the end-to-end tests exercise the SDK's actual transport — `URLSessionHTTPClient`,
/// URL construction, header injection, multipart body framing and JSON decoding — against bytes
/// copied from Anthropic's published responses. A `MockHTTPClient` skips all of that.
///
/// It listens on `127.0.0.1` only, and only for the lifetime of a test.
///
/// - Important: `NWParameters.acceptLocalOnly` is *not* loopback-only — Apple's header defines it
///   as "peers attached to the local link", which is the whole attached network segment. The
///   binding that actually confines this to the host is `requiredLocalEndpoint`; `acceptLocalOnly`
///   is kept as a second line of defence. `NWListener(using:on:)`'s `on:` argument is a *port*,
///   so `.any` there asks for an ephemeral port and says nothing about the address.
///
/// - Note: Apple platforms only. `Package.swift` declares no Linux support, but if that changes,
///   the `#else` branch below fails the build rather than deleting this suite silently.
final class LoopbackHTTPServer: @unchecked Sendable {

    /// Ceiling on a single request, head plus body. A peer that never sends a blank line, or
    /// announces a body larger than this, has its connection dropped instead of growing the buffer
    /// until the test process is killed.
    static let maxRequestBytes = 8 * 1024 * 1024

    /// A request as it arrived on the wire.
    struct ReceivedRequest: Sendable {
        /// e.g. `"GET"`.
        let method: String
        /// The request target, including any query string, e.g. `"/v1/skills?limit=2"`.
        let target: String
        /// Header names lowercased.
        let headers: [String: String]
        let body: Data

        /// The path with the query string stripped.
        var path: String { String(target.prefix(while: { $0 != "?" })) }

        /// Query parameters parsed from the request target, last value winning on a repeat.
        var query: [String: String] {
            guard let components = URLComponents(string: "http://127.0.0.1\(target)") else { return [:] }
            return (components.queryItems ?? []).queryValuesByName
        }
    }

    /// Produces the response for a request. Called on the server's queue.
    typealias Responder = @Sendable (ReceivedRequest) -> (status: Int, body: Data)

    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.taumatix.anthropic.loopback-http")
    private let responder: Responder
    private let lock = NSLock()
    private var _requests: [ReceivedRequest] = []

    /// Every request the server has received, in arrival order.
    var receivedRequests: [ReceivedRequest] { lock.withLock { _requests } }

    init(responder: @escaping Responder) throws {
        self.responder = responder
        let parameters = NWParameters.tcp
        // Confines the listener to 127.0.0.1. Without this the socket binds 0.0.0.0 and the
        // parser below is reachable from the local network segment.
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        parameters.acceptLocalOnly = true
        self.listener = try NWListener(using: parameters, on: .any)
    }

    /// Starts listening and returns the base URL to point a client at.
    func start() async throws -> URL {
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let resumed = Resumed()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard let port = self.listener.port?.rawValue else {
                        // Ready with no port is unrecoverable; resuming with an error beats
                        // hanging until the test times out.
                        if resumed.claim() { continuation.resume(throwing: StartupError.noPort) }
                        return
                    }
                    if resumed.claim() { continuation.resume(returning: port) }
                case .failed(let error):
                    if resumed.claim() { continuation.resume(throwing: error) }
                case .cancelled:
                    if resumed.claim() { continuation.resume(throwing: StartupError.cancelled) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }

        return URL(string: "http://127.0.0.1:\(port)")!
    }

    func stop() {
        listener.cancel()
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) {
            [weak self] chunk, _, isComplete, error in
            guard let self = self else { connection.cancel(); return }

            var buffer = buffer
            if let chunk = chunk { buffer.append(chunk) }

            guard buffer.count <= Self.maxRequestBytes else {
                connection.cancel()
                return
            }

            switch Self.parse(buffer) {
            case .complete(let request):
                self.lock.withLock { self._requests.append(request) }
                let (status, body) = self.responder(request)
                self.respond(on: connection, status: status, body: body)
            case .unparseable:
                connection.cancel()
            case .incomplete:
                // Keep reading unless the peer is done or the connection failed.
                if error != nil || isComplete {
                    connection.cancel()
                } else {
                    self.receive(connection, buffer: buffer)
                }
            }
        }
    }

    private func respond(on connection: NWConnection, status: Int, body: Data) {
        var head = "HTTP/1.1 \(status) \(Self.reason(for: status))\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"

        var response = Data(head.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Parsing

    /// The outcome of reading what has arrived so far.
    enum ParseResult {
        /// The head and the whole body are here.
        case complete(ReceivedRequest)
        /// Nothing is wrong yet; keep reading.
        case incomplete
        /// Malformed or unsupported. Drop the connection rather than guess.
        case unparseable
    }

    private static func parse(_ buffer: Data) -> ParseResult {
        let separator = Data("\r\n\r\n".utf8)
        guard let headEnd = buffer.range(of: separator) else { return .incomplete }

        let head = String(decoding: buffer[buffer.startIndex..<headEnd.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return .unparseable }

        let requestLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true)
        guard requestLine.count >= 2 else { return .unparseable }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        // A chunked body would leave Content-Length absent and the body silently empty, so a test
        // asserting on it would pass for the wrong reason. Refuse to parse it at all.
        guard headers["transfer-encoding"]?.lowercased().contains("chunked") != true else {
            return .unparseable
        }

        let expectedLength: Int
        if let raw = headers["content-length"] {
            // `Int("-1")` succeeds, `body.count >= -1` passes, and `prefix(-1)` then traps.
            guard let parsed = Int(raw), (0...maxRequestBytes).contains(parsed) else {
                return .unparseable
            }
            expectedLength = parsed
        } else {
            expectedLength = 0
        }

        let body = buffer[headEnd.upperBound...]
        guard body.count >= expectedLength else { return .incomplete }

        return .complete(ReceivedRequest(
            method: String(requestLine[0]),
            target: String(requestLine[1]),
            headers: headers,
            body: Data(body.prefix(expectedLength))
        ))
    }

    private static func reason(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        default: return "Status"
        }
    }

    enum StartupError: Error {
        /// The listener reported `.ready` without an assigned port.
        case noPort
        /// The listener was cancelled before it became ready.
        case cancelled
    }

    /// `NWListener.stateUpdateHandler` can fire more than once; a continuation may resume only once.
    private final class Resumed: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool {
            lock.withLock {
                if done { return false }
                done = true
                return true
            }
        }
    }
}
#endif
