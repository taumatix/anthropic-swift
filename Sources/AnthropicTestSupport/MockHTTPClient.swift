import Foundation
import Anthropic

/// A mock `HTTPClient` for use in unit tests.
///
/// Inject canned responses via `handler` and `streamHandler`,
/// then pass to `AnthropicClient` via `ClientConfiguration(apiKey:httpClient:)`.
///
/// ```swift
/// let mock = MockHTTPClient()
/// mock.handler = { request in
///     XCTAssertEqual(request.path, "/v1/messages")
///     return HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
/// }
/// let config = ClientConfiguration(apiKey: "test-key", httpClient: mock)
/// let client = AnthropicClient(configuration: config)
/// ```
public final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    public typealias Handler = @Sendable (HTTPRequest) async throws -> HTTPResponse
    public typealias StreamHandler = @Sendable (HTTPRequest) -> AsyncThrowingStream<Data, Error>

    /// Called when `send(_:)` is invoked. Override to return canned responses.
    public var handler: Handler?

    /// Called when `stream(_:)` is invoked. Override to return canned SSE data.
    public var streamHandler: StreamHandler?

    /// All requests recorded by `send(_:)` and `stream(_:)`.
    private var _requests: [HTTPRequest] = []
    private let lock = NSLock()

    public init() {}

    public var recordedRequests: [HTTPRequest] {
        lock.withLock { _requests }
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { _requests.append(request) }
        guard let handler = handler else {
            return HTTPResponse(statusCode: 200, body: Data("{}".utf8))
        }
        return try await handler(request)
    }

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        lock.withLock { _requests.append(request) }
        guard let streamHandler = streamHandler else {
            return AsyncThrowingStream { $0.finish() }
        }
        return streamHandler(request)
    }

    /// Resets recorded requests and handlers.
    public func reset() {
        lock.withLock {
            _requests.removeAll()
            handler = nil
            streamHandler = nil
        }
    }
}
