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

    /// The URL the mock reports its responses as coming from. `nil` means the request's own
    /// ``HTTPRequest/baseURL``, i.e. the origin the client was configured for, so a test passes the
    /// origin check by doing nothing.
    ///
    /// `RequestPipeline` refuses a response from any origin but the configured `baseURL`'s. Set this
    /// to another origin to see it refused. It is reported on both paths: as ``HTTPResponse/url``
    /// on a response the handler left without one, and to the `validate` of
    /// ``stream(_:validatingResponseFrom:)``.
    public var responseURL: URL?

    /// Whether the mock reports where responses came from at all. Turn it off to see a transport
    /// that does not say being refused, as `RequestPipeline` refuses it.
    public var reportsResponseURL = true

    public init() {}

    /// A mock that reports its responses as coming from `responseURL`.
    public convenience init(responseURL: URL?) {
        self.init()
        self.responseURL = responseURL
    }

    private func reportedURL(for request: HTTPRequest) -> URL? {
        lock.withLock { reportsResponseURL ? (responseURL ?? request.baseURL) : nil }
    }

    public var recordedRequests: [HTTPRequest] {
        lock.withLock { _requests }
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { _requests.append(request) }
        let response: HTTPResponse
        if let handler = handler {
            response = try await handler(request)
        } else {
            response = HTTPResponse(statusCode: 200, body: Data("{}".utf8))
        }
        guard response.url == nil, let responseURL = reportedURL(for: request) else {
            return response
        }
        return HTTPResponse(statusCode: response.statusCode, headers: response.headers, body: response.body, url: responseURL)
    }

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        lock.withLock { _requests.append(request) }
        guard let streamHandler = streamHandler else {
            return AsyncThrowingStream { $0.finish() }
        }
        return streamHandler(request)
    }

    public func stream(
        _ request: HTTPRequest,
        validatingResponseFrom validate: @escaping @Sendable (URL?) throws -> Void
    ) -> AsyncThrowingStream<Data, Error> {
        do {
            try validate(reportedURL(for: request))
        } catch {
            lock.withLock { _requests.append(request) }
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return stream(request)
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
