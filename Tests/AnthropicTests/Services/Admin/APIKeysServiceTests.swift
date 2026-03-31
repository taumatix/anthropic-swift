import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class APIKeysServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testListAPIKeys() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/api_keys")
            return HTTPResponse(statusCode: 200, body: MockResponses.apiKeyList)
        }
        let page = try await client.admin.apiKeys.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].status, .active)
    }

    func testGetAPIKey() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/api_keys/apikey_01Rj2N8SVvo6B5p8hqjjXqM4")
            return HTTPResponse(statusCode: 200, body: MockResponses.apiKey)
        }
        let key = try await client.admin.apiKeys.get(id: "apikey_01Rj2N8SVvo6B5p8hqjjXqM4")
        XCTAssertEqual(key.name, "My API Key")
    }
}
