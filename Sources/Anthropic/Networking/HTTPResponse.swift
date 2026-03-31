import Foundation

/// A value-type representation of an HTTP response.
public struct HTTPResponse: Sendable {
    /// HTTP status code.
    public let statusCode: Int
    /// Response headers.
    public let headers: [String: String]
    /// Response body data.
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
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
