import Foundation

/// Checks that a response came from the origin the caller configured.
///
/// ``CrossOriginRedirectGuard`` stops the SDK's own transport following a hop to another origin.
/// This is the check on the other side: whatever path a response took — a caller's `HTTPClient`,
/// a `URLProtocol` the app registered, a redirect nothing guarded — a body from another origin is
/// never decoded as Anthropic's answer.
enum ResponseOrigin {

    /// The error to throw for a response that arrived from `url`, or `nil` if it may be used.
    ///
    /// A `nil` `url` passes: the `HTTPClient` did not report one, and refusing would break every
    /// client written before ``HTTPResponse/url`` existed. The foreign body is not carried in the
    /// error, since it is exactly what must not reach the caller.
    static func refusal(for url: URL?, baseURL: URL) -> AnthropicError? {
        guard let url, !CrossOriginRedirectGuard.sameOrigin(url, baseURL) else { return nil }
        return .networkError(URLError(.badServerResponse, userInfo: [
            NSURLErrorFailingURLErrorKey: url,
            NSLocalizedDescriptionKey:
                "The response came from \(originDescription(url)), not the configured \(originDescription(baseURL)).",
        ]))
    }

    /// Scheme, host and port only: the path and query of either URL may carry things that do not
    /// belong in an error message.
    private static func originDescription(_ url: URL) -> String {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        return components.string ?? "an unknown origin"
    }
}
