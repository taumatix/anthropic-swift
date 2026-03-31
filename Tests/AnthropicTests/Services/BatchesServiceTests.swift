import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class BatchesServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testCreateBatch() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/v1/messages/batches")
            return HTTPResponse(statusCode: 200, body: MockResponses.messageBatch)
        }
        let batchRequest = BatchCreateRequest(requests: [
            BatchRequestItem(
                customId: "q1",
                params: MessageRequest(model: .claude4Haiku, messages: [.user("Hello")], maxTokens: 100)
            )
        ])
        let batch = try await client.batches.create(batchRequest)
        XCTAssertEqual(batch.id, "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d")
        XCTAssertEqual(batch.processingStatus, .inProgress)
    }

    func testGetBatch() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatch) }
        let batch = try await client.batches.get(id: "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d")
        XCTAssertEqual(batch.id, "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d")
    }

    func testListBatches() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatchList) }
        let page = try await client.batches.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].processingStatus, .ended)
    }

    func testCancelBatch() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertTrue(request.path.hasSuffix("/cancel"))
            return HTTPResponse(statusCode: 200, body: MockResponses.messageBatch)
        }
        let batch = try await client.batches.cancel(id: "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d")
        XCTAssertNotNil(batch)
    }

    func testDeleteBatch() async throws {
        let deleteBody = Data(#"{"id":"msgbatch_01","type":"message_batch_deleted"}"#.utf8)
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            return HTTPResponse(statusCode: 200, body: deleteBody)
        }
        let result = try await client.batches.delete(id: "msgbatch_01")
        XCTAssertEqual(result.id, "msgbatch_01")
    }
}
