import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class ModelsServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testListModels() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.modelsList) }
        let page = try await client.models.list()
        XCTAssertEqual(page.data.count, 2)
        XCTAssertEqual(page.data[0].id, "claude-opus-4-5")
        XCTAssertFalse(page.hasMore)
    }

    func testListModelsSendsGetToCorrectPath() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/v1/models")
            return HTTPResponse(statusCode: 200, body: MockResponses.modelsList)
        }
        _ = try await client.models.list()
    }

    func testGetModel() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/models/claude-opus-4-5")
            return HTTPResponse(statusCode: 200, body: MockResponses.singleModel)
        }
        let model = try await client.models.get(id: "claude-opus-4-5")
        XCTAssertEqual(model.id, "claude-opus-4-5")
        XCTAssertEqual(model.displayName, "Claude Opus 4.5")
    }
}
