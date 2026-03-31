import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class StreamingServiceTests: XCTestCase {

    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func makeRequest() -> MessageRequest {
        MessageRequest(model: .claude4Sonnet, messages: [.user("Tell me a story.")], maxTokens: 512)
    }

    // MARK: - textStream

    func testTextStreamYieldsTextDeltas() async throws {
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream) }

        var texts: [String] = []
        for try await text in client.messages.stream(makeRequest()).textStream {
            texts.append(text)
        }
        // basicMessageStream has two text_delta events: "Hello" and "!"
        XCTAssertEqual(texts, ["Hello", "!"])
    }

    // MARK: - collect

    func testCollectAssemblesMessageResponse() async throws {
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream) }

        let response = try await client.messages.stream(makeRequest()).collect()
        XCTAssertEqual(response.id, "msg_01XFDUDYJgAACzvnptvVoYEL")
        XCTAssertEqual(response.textContent, "Hello!")
        XCTAssertEqual(response.stopReason, .endTurn)
    }

    // MARK: - Events

    func testStreamEmitsCorrectEventSequence() async throws {
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream) }

        var eventTypes: [String] = []
        for try await event in client.messages.stream(makeRequest()) {
            switch event {
            case .messageStart: eventTypes.append("messageStart")
            case .contentBlockStart: eventTypes.append("contentBlockStart")
            case .contentBlockDelta: eventTypes.append("contentBlockDelta")
            case .contentBlockStop: eventTypes.append("contentBlockStop")
            case .messageDelta: eventTypes.append("messageDelta")
            case .messageStop: eventTypes.append("messageStop")
            case .ping: eventTypes.append("ping")
            case .error: eventTypes.append("error")
            case .unknown: eventTypes.append("unknown")
            }
        }

        XCTAssertTrue(eventTypes.contains("messageStart"))
        XCTAssertTrue(eventTypes.contains("messageStop"))
        XCTAssertTrue(eventTypes.contains("contentBlockDelta"))
    }

    // MARK: - Error in stream

    func testErrorEventThrows() async throws {
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.errorStream) }

        do {
            for try await _ in client.messages.stream(makeRequest()) { }
            XCTFail("Should have thrown")
        } catch AnthropicError.apiError(let apiError) {
            XCTAssertEqual(apiError.error.type, "api_error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Tool use stream

    func testToolUseStreamCollects() async throws {
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.toolUseStream) }

        let response = try await client.messages.stream(makeRequest()).collect()
        XCTAssertNotNil(response.firstToolUse)
        XCTAssertEqual(response.firstToolUse?.name, "get_weather")
        XCTAssertEqual(response.stopReason, .toolUse)
    }
}
