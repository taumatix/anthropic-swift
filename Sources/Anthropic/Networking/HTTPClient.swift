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
}
