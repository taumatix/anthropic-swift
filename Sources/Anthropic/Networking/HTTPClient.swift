import Foundation

/// The core networking abstraction for the Anthropic SDK.
///
/// All HTTP communication goes through this protocol. The production implementation
/// uses `URLSession`; tests inject `MockHTTPClient` from `AnthropicTestSupport`.
///
/// - Important: Never call `URLSession` directly from a service. Always go through
///   this protocol so requests can be intercepted in tests.
public protocol HTTPClient: Sendable {
    /// Sends a request and returns the complete response.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse

    /// Sends a request and returns a stream of raw data chunks (for SSE).
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error>

    /// Streams like ``stream(_:)``, but first passes the URL the response actually came from —
    /// after any redirects — to `validate`, and yields nothing if it throws. Finish the stream with
    /// the error `validate` threw.
    ///
    /// `RequestPipeline` streams through this, with a `validate` that refuses a response from any
    /// origin but `baseURL`'s. A unary response carries ``HTTPResponse/url`` for the same check;
    /// a stream has no response object, so this is how its origin reaches the pipeline.
    ///
    /// The default implementation calls ``stream(_:)`` and never calls `validate`, so a client
    /// written before this method existed keeps working, unchecked. Implement it to be checked.
    func stream(
        _ request: HTTPRequest,
        validatingResponseFrom validate: @escaping @Sendable (URL?) throws -> Void
    ) -> AsyncThrowingStream<Data, Error>
}

extension HTTPClient {
    public func stream(
        _ request: HTTPRequest,
        validatingResponseFrom validate: @escaping @Sendable (URL?) throws -> Void
    ) -> AsyncThrowingStream<Data, Error> {
        stream(request)
    }
}
