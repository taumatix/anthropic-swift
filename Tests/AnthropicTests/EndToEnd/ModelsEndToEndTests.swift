#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// End-to-end tests for the Models API over a real TCP socket, replaying the response bodies
/// Anthropic publishes (retrieved 2026-10-09). Not covered: that Anthropic still serves these
/// bodies, and the `lifecycle` list filter (not implemented).
final class ModelsEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    func testListAndGetDecodeTheDocumentedBodiesOverARealSocket() async throws {
        let server = try LoopbackHTTPServer { request in
            switch (request.method, request.path) {
            case ("GET", "/v1/models"):
                return .json(200, MockResponses.modelsList)
            case ("GET", "/v1/models/claude-opus-5"):
                return .json(200, MockResponses.singleModel)
            default:
                return .json(404, Data(#"{"type":"error","error":{"type":"not_found_error","message":"Not found"}}"#.utf8))
            }
        }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))

        let page = try await client.models.list(limit: 1)
        XCTAssertEqual(page.data.map(\.id), ["claude-opus-5"])
        XCTAssertEqual(page.data[0].capabilities?.thinking?.types?.adaptive?.supported, true)

        let model = try await client.models.get(id: "claude-opus-5")
        XCTAssertEqual(model, page.data[0])
        XCTAssertEqual(model.lifecycle, "active")
    }
}
#endif
