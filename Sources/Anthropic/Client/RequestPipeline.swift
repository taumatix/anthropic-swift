import Foundation

/// The request execution pipeline.
///
/// Responsible for:
/// 1. Injecting auth headers (`x-api-key`, `anthropic-version`)
/// 2. Injecting `content-type` and `accept` headers
/// 3. Merging client-level `additionalHeaders`
/// 4. Executing the request through the `HTTPClient` protocol
/// 5. Applying retry logic for retryable status codes
/// 6. Throwing `AnthropicError` for non-2xx responses
public final class RequestPipeline: Sendable {
    private let configuration: ClientConfiguration

    public init(configuration: ClientConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Non-Streaming

    /// Sends a request and returns the decoded response body.
    public func send<T: Decodable>(_ request: HTTPRequest) async throws -> T {
        let response = try await sendRaw(request)
        do {
            return try JSONCoding.decoder.decode(T.self, from: response.body)
        } catch let error as DecodingError {
            throw AnthropicError.decodingError(error, rawBody: response.body)
        }
    }

    /// Sends a request and returns the raw `HTTPResponse`.
    public func sendRaw(_ request: HTTPRequest) async throws -> HTTPResponse {
        var attempt = 0
        while true {
            let prepared = prepare(request, isAdmin: isAdminPath(request.path))
            let response = try await configuration.httpClient.send(prepared)

            if response.isSuccess { return response }

            if configuration.retryPolicy.shouldRetry(response: response, attempt: attempt, maxRetries: configuration.maxRetries) {
                let delay = configuration.retryPolicy.delay(for: response, attempt: attempt)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                attempt += 1
                continue
            }

            throw AnthropicError.from(response: response)
        }
    }

    // MARK: - Streaming

    /// Returns a stream of raw `Data` chunks for an SSE request.
    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        let prepared = prepare(request, isAdmin: false)
        return configuration.httpClient.stream(prepared)
    }

    // MARK: - Helpers

    private func prepare(_ request: HTTPRequest, isAdmin: Bool) -> HTTPRequest {
        var req = request
        let apiKey = isAdmin ? (configuration.adminAPIKey ?? configuration.apiKey) : configuration.apiKey

        var headers: [String: String] = [
            "x-api-key": apiKey,
            "anthropic-version": configuration.anthropicVersion,
            "accept": "application/json",
        ]
        // Only set content-type for requests with a body; multipart sets its own
        if request.body != nil && request.headers["content-type"] == nil {
            headers["content-type"] = "application/json"
        }
        // Merge: request headers take precedence over pipeline defaults
        headers = HeaderBuilder.merge(base: headers, additional: configuration.additionalHeaders)
        headers = HeaderBuilder.merge(base: headers, additional: request.headers)
        req.headers = headers
        return req
    }

    private func isAdminPath(_ path: String) -> Bool {
        path.hasPrefix("/v1/organizations")
    }
}
