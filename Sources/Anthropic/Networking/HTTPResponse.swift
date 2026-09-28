import Foundation

/// A value-type representation of an HTTP response.
public struct HTTPResponse: Sendable {
    /// HTTP status code.
    public let statusCode: Int
    /// Response headers.
    public let headers: [String: String]
    /// Response body data.
    public let body: Data
    /// The URL the response actually came from, after any redirects.
    ///
    /// `RequestPipeline` refuses a response whose origin (scheme, host, port) differs from the
    /// configured `baseURL`'s. `nil` means the `HTTPClient` did not say, and skips that check —
    /// which keeps a client written before this property existed working, and is also why a
    /// custom `HTTPClient` should set it.
    public let url: URL?

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data(), url: URL? = nil) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.url = url
    }

    /// Returns `true` if the status code is in the 2xx range.
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }

    /// The value of the `request-id` header returned by the Anthropic API.
    public var requestID: String? {
        headers["request-id"]
    }

    /// The value of the `Retry-After` header, parsed as a `TimeInterval`.
    public var retryAfter: TimeInterval? {
        headers["retry-after"].flatMap { Double($0) }
    }
}
