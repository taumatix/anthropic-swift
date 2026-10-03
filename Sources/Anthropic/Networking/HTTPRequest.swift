import Foundation

/// A value-type representation of an HTTP request.
public struct HTTPRequest: Sendable {
    /// HTTP method (e.g., "GET", "POST", "DELETE", "PATCH").
    public var method: String
    /// Request path, relative to the client's base URL (e.g., "/v1/messages").
    public var path: String
    /// HTTP headers. The `RequestPipeline` merges auth and version headers before sending.
    public var headers: [String: String]
    /// Request body data, or `nil` for requests with no body.
    public var body: Data?
    /// Query parameters appended to the URL.
    public var queryItems: [URLQueryItem]
    /// How long the request may go without receiving data before it fails, in seconds, or `nil`
    /// for the transport's own default. `RequestPipeline` sets it from
    /// ``ClientConfiguration/timeout``; a custom ``HTTPClient`` should honour it.
    public var timeout: TimeInterval?

    public init(
        method: String,
        path: String,
        headers: [String: String] = [:],
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        timeout: TimeInterval? = nil
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
        self.queryItems = queryItems
        self.timeout = timeout
    }

    /// Builds the full `URLRequest` for the given base URL.
    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw AnthropicError.encodingError(
                EncodingError.invalidValue(path, .init(codingPath: [], debugDescription: "Could not build URL from path: \(path)"))
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        // Per request, rather than on a session built from the configuration: that would change
        // connection pooling and cookie scope for every caller, where this changes only what
        // the setting promised. It overrides the session's own 60s per-request default, and
        // bounds the gap between packets, which is what a long streaming turn needs.
        if let timeout, timeout > 0 {
            urlRequest.timeoutInterval = timeout
        }
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        return urlRequest
    }
}
