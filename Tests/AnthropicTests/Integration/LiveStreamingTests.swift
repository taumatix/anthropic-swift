import XCTest
import Anthropic

final class LiveStreamingTests: IntegrationTestCase {

    func testStreamingTextDeltas() async throws {
        let request = MessageRequest(
            model: .claude4Haiku,
            messages: [.user("Count from 1 to 5.")],
            maxTokens: 100
        )

        var texts: [String] = []
        for try await text in client.messages.stream(request).textStream {
            texts.append(text)
        }
        XCTAssertFalse(texts.isEmpty)
        let joined = texts.joined()
        XCTAssertFalse(joined.isEmpty)
    }

    func testStreamingCollect() async throws {
        let request = MessageRequest(
            model: .claude4Haiku,
            messages: [.user("Say 'hi' and nothing else.")],
            maxTokens: 50
        )

        let response = try await client.messages.stream(request).collect()
        XCTAssertFalse(response.id.isEmpty)
        XCTAssertFalse(response.textContent.isEmpty)
        XCTAssertEqual(response.stopReason, .endTurn)
    }
}
