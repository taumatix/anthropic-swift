import XCTest
@testable import Anthropic
import AnthropicTestSupport

/// Tests for RequestPipeline and URLSessionHTTPClient behaviour that are not
/// covered by the per-service test suites.
final class RequestPipelineTests: XCTestCase {

    // MARK: - stream() error propagation path (C3 fix)

    /// Verifies that errors thrown inside a `MockHTTPClient.streamHandler`
    /// are propagated correctly through `RequestPipeline.stream()` to the
    /// caller — exercising the stream error path that was previously only
    /// reachable via a direct `try?`-wrapped bypass.
    func testStreamPropagatesErrorFromMockStreamHandler() async throws {
        let mock = MockHTTPClient()
        mock.streamHandler = { _ in
            AsyncThrowingStream { continuation in
                continuation.finish(throwing: AnthropicError.streamParseError("simulated parse failure"))
            }
        }
        let config = ClientConfiguration(apiKey: "test-key", httpClient: mock)
        let client = AnthropicClient(configuration: config)

        var thrownError: Error?
        do {
            for try await _ in client.messages.stream(
                MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 10)
            ) { }
        } catch {
            thrownError = error
        }

        guard let anthropicError = thrownError as? AnthropicError,
              case .streamParseError(let msg) = anthropicError else {
            XCTFail("Expected AnthropicError.streamParseError, got: \(String(describing: thrownError))")
            return
        }
        XCTAssertEqual(msg, "simulated parse failure")
    }

    // MARK: - Pipeline calls through HTTPClient protocol (C1/C2 regression)

    /// Verifies that RequestPipeline calls MockHTTPClient.send(_:) via the
    /// HTTPClient protocol — not via an internal bypass — by confirming that
    /// a mock can intercept and return a response without any fatalError.
    func testPipelineCallsMockClientViaProtocol() async throws {
        let mock = MockHTTPClient()
        mock.handler = { _ in
            HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
        }
        let config = ClientConfiguration(apiKey: "test-key", httpClient: mock)
        let client = AnthropicClient(configuration: config)

        let response = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 10)
        )
        XCTAssertFalse(response.id.isEmpty)
        XCTAssertEqual(mock.recordedRequests.count, 1)
    }

    // MARK: - Retry integration (W6 coverage)

    /// Verifies that the pipeline actually retries on a 500 response: the mock
    /// returns 500 once, then 200, and we assert two recorded requests.
    func testPipelineRetriesOn500() async throws {
        let mock = MockHTTPClient()
        nonisolated(unsafe) var callCount = 0
        mock.handler = { _ in
            callCount += 1
            if callCount == 1 {
                return HTTPResponse(statusCode: 500, body: Data())
            }
            return HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
        }
        let config = ClientConfiguration(apiKey: "test-key", maxRetries: 1, retryPolicy: .init(
            strategy: .exponentialBackoff(base: 0.001, multiplier: 1.0, maxDelay: 0.001),
            retryableStatusCodes: [500]
        ), httpClient: mock)
        let client = AnthropicClient(configuration: config)

        let response = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 10)
        )
        XCTAssertFalse(response.id.isEmpty)
        XCTAssertEqual(callCount, 2, "Pipeline should have retried once (2 total calls)")
    }
}
