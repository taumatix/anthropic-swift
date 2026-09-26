import Foundation

/// Refuses to follow a redirect that leaves the origin the caller configured.
///
/// `URLSession` follows redirects itself and replays the original request onto the target,
/// stripping nothing — not `Authorization`, and not the custom `x-api-key` this SDK authenticates
/// with. So anything able to answer with a `302` can harvest the caller's API key: the gateway
/// they pointed `baseURL` at, a compromised one, or whoever can answer on a plaintext endpoint.
///
/// ## Why refuse rather than strip the credentials
///
/// The first version of this guard removed credential headers and let the redirect proceed. That
/// is not enough, and a security review demonstrated both halves against two loopback listeners:
///
/// - **The body crosses.** 307 and 308 preserve the method and body, so the foreign origin
///   received the whole `POST /v1/messages` — prompt, system prompt and tool results — and, for
///   `files.upload`, the complete multipart body with the filename and file bytes. Dropping the
///   key protects the credential and leaks the conversation instead.
/// - **The foreign response comes back as the API's answer.** Nothing re-checks where a response
///   came from, so the attacker's body decoded into a `MessageResponse` and their SSE parsed into
///   real `MessageStreamEvent`s. An application that feeds assistant output into tool dispatch, a
///   shell, or a UI would then act on attacker-chosen content believing Anthropic sent it.
///
/// Refusing closes both, and closes a third: `BaseURLPolicy` validates `baseURL` once per send, so
/// a redirect was the way to reach `http://10.1.2.3` from an `https://` base and escape the
/// transport guarantee entirely.
///
/// Returning `nil` from the delegate makes `URLSession` deliver the 3xx response itself instead of
/// following it. `HTTPResponse` treats only `200..<300` as success, so the caller gets
/// `AnthropicError.httpError(statusCode: 302, body:)` — a failure that names the hop, rather than
/// an unexplained 401 from a stranger.
///
/// Same-origin redirects are followed untouched: a server moving a path is entitled to the
/// credentials the caller sent it.
///
/// If a cross-origin target ever becomes legitimate — a Files CDN, say — it belongs behind an
/// explicit allowlist of permitted targets, not behind "strip and hope".
final class CrossOriginRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    /// Stateless, so one instance serves every task.
    static let shared = CrossOriginRedirectGuard()

    /// Scheme, host and port must all match. A `nil` on either side is treated as a mismatch, so an
    /// unexpected shape refuses rather than trusts.
    ///
    /// Comparison is against the *original* request, not the previous hop, so a chain that leaves
    /// the caller's origin can never work its way back to being trusted.
    static func sameOrigin(_ lhs: URL?, _ rhs: URL?) -> Bool {
        guard let lhs, let rhs,
              let lhsHost = lhs.host, let rhsHost = rhs.host,
              let lhsScheme = lhs.scheme, let rhsScheme = rhs.scheme
        else { return false }

        return lhsScheme.lowercased() == rhsScheme.lowercased()
            && lhsHost.lowercased() == rhsHost.lowercased()
            && defaultedPort(of: lhs) == defaultedPort(of: rhs)
    }

    /// An absent port means the scheme's default, so `https://h` and `https://h:443` are one origin
    /// — and likewise `http://h` and `http://h:80`, which matters for a plaintext gateway running
    /// under ``ClientConfiguration/allowsInsecureBaseURL``.
    private static func defaultedPort(of url: URL) -> Int? {
        if let port = url.port { return port }
        switch url.scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return nil
        }
    }

    // MARK: - URLSessionTaskDelegate

    // The completion-handler spelling rather than the `async` one: this is the form
    // `URLSessionTaskDelegate` declares on every platform the package supports, and it is what
    // CFNetwork calls.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard Self.sameOrigin(request.url, task.originalRequest?.url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
