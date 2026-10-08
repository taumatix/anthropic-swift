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
        XCTAssertEqual(batch.id, "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF")
        XCTAssertEqual(batch.processingStatus, .inProgress)
    }

    func testGetBatch() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatch) }
        let batch = try await client.batches.get(id: "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF")
        XCTAssertEqual(batch.id, "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF")
    }

    func testListBatches() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatchList) }
        let page = try await client.batches.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].processingStatus, .inProgress)
    }

    func testCancelBatch() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertTrue(request.path.hasSuffix("/cancel"))
            return HTTPResponse(statusCode: 200, body: MockResponses.messageBatch)
        }
        let batch = try await client.batches.cancel(id: "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF")
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

    func testGetDecodesTheDocumentedBodyIncludingArchivedAt() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatch) }
        let batch = try await client.batches.get(id: "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF")
        XCTAssertEqual(batch.archivedAt, "2024-08-20T18:37:24.100435Z")
        XCTAssertEqual(batch.cancelInitiatedAt, "2024-08-20T18:37:24.100435Z")
        XCTAssertEqual(batch.requestCounts, BatchRequestCounts(processing: 100, succeeded: 50, errored: 30, canceled: 10, expired: 10))
        XCTAssertEqual(batch.resultsUrl, "https://api.anthropic.com/v1/messages/batches/msgbatch_013Zva2CMHLNnXjNJJKqJ2EF/results")
    }

    func testBodyWithoutArchivedAtStillDecodes() throws {
        let body = Data(#"""
        {"id":"msgbatch_1","type":"message_batch","processing_status":"ended",
         "request_counts":{"processing":0,"succeeded":1,"errored":0,"canceled":0,"expired":0},
         "ended_at":null,"created_at":"2024-09-24T18:37:24Z","expires_at":"2024-09-25T18:37:24Z",
         "cancel_initiated_at":null,"results_url":null}
        """#.utf8)
        let batch = try JSONCoding.decoder.decode(MessageBatch.self, from: body)
        XCTAssertNil(batch.archivedAt)
    }

    func testListEnvelopeCarriesFirstAndLastIds() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatchList) }
        let page = try await client.batches.list(limit: 1)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.firstId, "first_id")
        XCTAssertEqual(page.lastId, "last_id")
    }

    func testIdsArePercentEncodedInPaths() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.messageBatch) }
        _ = try await client.batches.get(id: "a/b c")
        XCTAssertEqual(mock.recordedRequests.last?.path, "/v1/messages/batches/a%2Fb%20c")
    }

    func testResultOutcomesDecodeTheDocumentedShapes() throws {
        let errored = Data(#"""
        {"custom_id":"q2","result":{"type":"errored","error":{"type":"error",
         "error":{"type":"invalid_request_error","message":"Invalid request"},"request_id":null}}}
        """#.utf8)
        guard case .errored(let error) = try JSONCoding.decoder.decode(BatchResult.self, from: errored).result else {
            return XCTFail("expected errored")
        }
        XCTAssertEqual(error.error.type, "invalid_request_error")
        for kind in ["canceled", "expired"] {
            let line = Data(#"{"custom_id":"q","result":{"type":"\#(kind)"}}"#.utf8)
            let result = try JSONCoding.decoder.decode(BatchResult.self, from: line).result
            switch (kind, result) {
            case ("canceled", .canceled), ("expired", .expired): break
            default: XCTFail("\(kind) decoded as \(result)")
            }
        }
    }
}
