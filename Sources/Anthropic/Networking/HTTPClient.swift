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
    ///
    /// Set ``HTTPResponse/url`` to where the response came from, after any redirects. A response
    /// with no `url` is refused. A client that does not know better can report ``HTTPRequest/baseURL``.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse

    /// Streams the response to a request as raw data chunks (for SSE), first passing the URL the
    /// response actually came from — after any redirects — to `validate`, and yielding nothing if it
    /// throws. Finish the stream with the error `validate` threw. `validate` must be called, with
    /// `nil` if the client cannot tell, which `validate` refuses.
    ///
    /// `RequestPipeline` streams through this, with a `validate` that refuses a response from any
    /// origin but `baseURL`'s. A unary response carries ``HTTPResponse/url`` for the same check;
    /// a stream has no response object, so this is how its origin reaches the pipeline.
    func stream(
        _ request: HTTPRequest,
        validatingResponseFrom validate: @escaping @Sendable (URL?) throws -> Void
    ) -> AsyncThrowingStream<Data, Error>
}

extension HTTPClient {
    /// Streams without checking where the response came from. For code that holds an `HTTPClient`
    /// of its own and wants the raw chunks; `RequestPipeline` never calls it.
    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        stream(request, validatingResponseFrom: { _ in })
    }
}
