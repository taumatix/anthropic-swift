import XCTest
import Anthropic
import AnthropicTestSupport

/// `MockHTTPClient.responseURL` lets a test put a response's origin in front of the pipeline's
/// origin check, on both paths, the way `URLSessionHTTPClient` does. Without it a mock reports no
/// origin, which the check lets through, so a test against the mock could not show whether the
/// production transport would be refused.
final class MockResponseURLTests: XCTestCase {

    private let base = URL(string: "https://api.anthropic.com")!
    private let foreign = URL(string: "https://attacker.example/v1/messages")!

    private func client(_ mock: MockHTTPClient) -> AnthropicClient {
        AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", baseURL: base, maxRetries: 0, httpClient: mock))
    }

    private func mock(responseURL: URL?) -> MockHTTPClient {
        let mock = MockHTTPClient(responseURL: responseURL)
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream) }
        return mock
    }

    private let request = MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)

    func testAForeignResponseURLIsRefusedOnAUnaryCall() async throws {
        do {
            _ = try await client(mock(responseURL: foreign)).messages.create(request)
            XCTFail("a response the mock reported from another origin was accepted")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
            XCTAssertEqual(error.failingURL?.host, "attacker.example")
        }
    }

    func testAForeignResponseURLIsRefusedOnAStream() async throws {
        var events = 0
        do {
            for try await _ in client(mock(responseURL: foreign)).messages.stream(request) { events += 1 }
            XCTFail("a stream the mock reported from another origin was delivered")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }
        XCTAssertEqual(events, 0)
    }

    func testASameOriginResponseURLPassesOnBothPaths() async throws {
        let c = client(mock(responseURL: base.appendingPathComponent("v1/messages")))
        _ = try await c.messages.create(request)
        var events = 0
        for try await _ in c.messages.stream(request) { events += 1 }
        XCTAssertGreaterThan(events, 0)
    }

    /// The default is the behaviour every existing test was written against.
    func testWithoutAResponseURLNothingChanges() async throws {
        let c = client(mock(responseURL: nil))
        _ = try await c.messages.create(request)
        var events = 0
        for try await _ in c.messages.stream(request) { events += 1 }
        XCTAssertGreaterThan(events, 0)
    }

    /// A handler that sets its own URL is describing that one response, and wins.
    func testAURLTheHandlerSetIsKept() async throws {
        let mock = MockHTTPClient(responseURL: base)
        mock.handler = { [foreign] _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage, url: foreign) }
        do {
            _ = try await client(mock).messages.create(request)
            XCTFail("the handler's own URL was overwritten")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }
}
