#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// End-to-end tests for the Batches API over a real TCP socket, replaying response bodies in the
/// shapes Anthropic publishes (retrieved 2026-10-09). Not covered: that Anthropic still returns
/// these bodies, and a live batch run (no API key here).
final class BatchesEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    func testCreateGetListAndStreamedResultsOverARealSocket() async throws {
        let jsonl = [
            #"{"custom_id":"q1","result":{"type":"succeeded","message":"# + String(decoding: MockResponses.singleMessage, as: UTF8.self).components(separatedBy: .newlines).joined() + #"}}"#,
            #"{"custom_id":"q2","result":{"type":"errored","error":{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"},"request_id":null}}}"#,
            #"{"custom_id":"q3","result":{"type":"canceled"}}"#,
            #"{"custom_id":"q4","result":{"type":"expired"}}"#,
        ].joined(separator: "\n") + "\n"
        let server = try LoopbackHTTPServer { request in
            switch (request.method, request.path) {
            case ("POST", "/v1/messages/batches"), ("GET", "/v1/messages/batches/msgbatch_013Zva2CMHLNnXjNJJKqJ2EF"):
                return .json(200, MockResponses.messageBatch)
            case ("GET", "/v1/messages/batches"):
                return .json(200, MockResponses.messageBatchList)
            case ("GET", "/v1/messages/batches/msgbatch_013Zva2CMHLNnXjNJJKqJ2EF/results"):
                return .json(200, Data(jsonl.utf8))
            default:
                return .json(404, Data(#"{"type":"error","error":{"type":"not_found_error","message":"Not found"}}"#.utf8))
            }
        }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))

        let created = try await client.batches.create(BatchCreateRequest(requests: [
            BatchRequestItem(customId: "q1", params: MessageRequest(model: .claude4Haiku, messages: [.user("Hi")], maxTokens: 10))
        ]))
        XCTAssertEqual(created.archivedAt, "2024-08-20T18:37:24.100435Z")
        let fetched = try await client.batches.get(id: created.id)
        XCTAssertEqual(fetched, created)
        let page = try await client.batches.list(limit: 1)
        XCTAssertEqual(page.data.map(\.id), [created.id])

        var outcomes: [String] = []
        for try await result in client.batches.results(id: created.id) {
            switch result.result {
            case .succeeded: outcomes.append("\(result.customId):succeeded")
            case .errored(let e): outcomes.append("\(result.customId):\(e.error.type)")
            case .canceled: outcomes.append("\(result.customId):canceled")
            case .expired: outcomes.append("\(result.customId):expired")
            }
        }
        XCTAssertEqual(outcomes, ["q1:succeeded", "q2:overloaded_error", "q3:canceled", "q4:expired"])
        XCTAssertEqual(server.receivedRequests.first?.method, "POST")
    }
}
#endif
