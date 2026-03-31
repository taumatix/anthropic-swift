import XCTest
import Anthropic

final class LiveMessagesTests: IntegrationTestCase {

    func testCreateSimpleMessage() async throws {
        let response = try await client.messages.create(
            MessageRequest(
                model: .claude4Haiku,
                messages: [.user("Say 'hello' and nothing else.")],
                maxTokens: 50
            )
        )
        XCTAssertFalse(response.id.isEmpty)
        XCTAssertFalse(response.textContent.isEmpty)
        XCTAssertEqual(response.stopReason, .endTurn)
        XCTAssertGreaterThan(response.usage.outputTokens, 0)
    }

    func testCountTokens() async throws {
        let response = try await client.messages.countTokens(
            CountTokensRequest(
                model: .claude4Haiku,
                messages: [.user("Hello world")]
            )
        )
        XCTAssertGreaterThan(response.inputTokens, 0)
    }

    func testListModels() async throws {
        let page = try await client.models.list()
        XCTAssertFalse(page.data.isEmpty)
    }
}
