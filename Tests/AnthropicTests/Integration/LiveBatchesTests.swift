import XCTest
import Anthropic

/// Message Batches against `api.anthropic.com`. Creates one one-request batch and cancels it at
/// once, so it bills at most a few tokens of Haiku.
final class LiveBatchesTests: IntegrationTestCase {

    func testCreateGetListCancelRoundTrip() async throws {
        let created = try await client.batches.create(BatchCreateRequest(requests: [
            BatchRequestItem(
                customId: "live-1",
                params: MessageRequest(model: .claudeHaiku55, messages: [.user("Say hi.")], maxTokens: 8))
        ]))
        XCTAssertEqual(created.type, "message_batch")
        XCTAssertTrue(created.id.hasPrefix("msgbatch_"), created.id)
        XCTAssertEqual(created.requestCounts.processing + created.requestCounts.succeeded, 1)

        let fetched = try await client.batches.get(id: created.id)
        XCTAssertEqual(fetched.id, created.id)

        let canceled = try await client.batches.cancel(id: created.id)
        XCTAssertEqual(canceled.id, created.id)
        XCTAssertNotNil(canceled.cancelInitiatedAt, "cancel returned no cancel_initiated_at")

        let page = try await client.batches.list(limit: 5)
        XCTAssertFalse(page.data.isEmpty)
    }
}
