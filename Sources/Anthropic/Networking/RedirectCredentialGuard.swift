import Foundation

/// Drops every header the SDK or its caller added when a redirect leaves the origin the caller
/// configured.
///
/// `URLSession` follows redirects itself and replays the original request's headers onto the
/// target, stripping nothing — not `Authorization`, and not a custom header like the `x-api-key`
/// this SDK authenticates with. So anything able to answer with a `302` can harvest the caller's
/// API key: the gateway they pointed `baseURL` at, a compromised one, or whoever can answer on a
/// plaintext endpoint. Verified against two loopback listeners in `RedirectCredentialTests`, where
/// the second one received `x-api-key` on 301, 302, 307 and 308, from both `data(for:)` and
/// `bytes(for:)`.
///
/// ## The rule is an allowlist, deliberately
///
/// On an origin change the redirected request keeps only ``hopSafeHeaders`` and loses everything
/// else. A denylist of "the credential headers" would have to be extended every time this SDK
/// starts sending a new one, and the failure mode of forgetting is silent. An allowlist protects a
/// header nobody has written yet, and covers `additionalHeaders` — where a caller's gateway token
/// lives — without this type needing to know the configuration.
///
/// Same-origin redirects are left alone: a server moving a path is entitled to the credentials the
/// caller sent it, and stripping there would turn every legitimate redirect into a 401.
final class RedirectCredentialGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    /// Headers that may cross an origin boundary: content negotiation, framing, and who we are.
    /// None of them authenticates anything.
    ///
    /// `host`, `connection` and `content-length` are `URLSession`'s to set, and are listed so that
    /// preserving them is a statement rather than an accident.
    static let hopSafeHeaders: Set<String> = [
        "accept",
        "accept-charset",
        "accept-encoding",
        "accept-language",
        "connection",
        "content-length",
        "content-type",
        "host",
        "user-agent",
    ]

    /// Stateless, so one instance serves every task.
    static let shared = RedirectCredentialGuard()

    /// Returns the request `URLSession` should actually send, with credentials removed if the
    /// redirect changes origin.
    ///
    /// Exposed separately from the delegate callback so the decision can be tested without a
    /// `URLSessionTask`.
    static func sanitize(_ request: URLRequest, origin: URL?) -> URLRequest {
        guard !sameOrigin(request.url, origin) else { return request }

        var sanitized = request
        for name in request.allHTTPHeaderFields?.keys ?? [:].keys
        where !hopSafeHeaders.contains(name.lowercased()) {
            sanitized.setValue(nil, forHTTPHeaderField: name)
        }
        return sanitized
    }

    /// Scheme, host and port must all match. A `nil` on either side is treated as a mismatch, so an
    /// unexpected shape strips rather than trusts.
    ///
    /// Comparison is against the *original* request, not the previous hop, so credentials survive
    /// only while the conversation is still with the endpoint the caller named. A chain that leaves
    /// and comes back does not get them again.
    private static func sameOrigin(_ lhs: URL?, _ rhs: URL?) -> Bool {
        guard let lhs, let rhs,
              let lhsHost = lhs.host, let rhsHost = rhs.host,
              let lhsScheme = lhs.scheme, let rhsScheme = rhs.scheme
        else { return false }

        return lhsScheme.lowercased() == rhsScheme.lowercased()
            && lhsHost.lowercased() == rhsHost.lowercased()
            && defaultedPort(of: lhs) == defaultedPort(of: rhs)
    }

    /// An absent port means the scheme's default, so `https://h` and `https://h:443` are one origin.
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
        completionHandler(Self.sanitize(request, origin: task.originalRequest?.url))
    }
}
