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
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].id, "claude-opus-5")
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.firstId, "first_id")
        XCTAssertEqual(page.lastId, "last_id")
    }

    func testDocumentedBodyDecodesEveryField() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleModel) }
        let m = try await client.models.get(id: "claude-opus-5")
        XCTAssertEqual(m.displayName, "Claude Opus 5")
        XCTAssertEqual(m.createdAt, "2026-07-24T00:00:00Z")
        XCTAssertEqual(m.lifecycle, "active")
        XCTAssertEqual(m.line, "haiku")
        XCTAssertEqual(m.deprecatedAt, "2019-12-27T18:11:19.117Z")
        XCTAssertEqual(m.retiresAt, "2019-12-27T18:11:19.117Z")
        XCTAssertEqual(m.maxInputTokens, 0)
        XCTAssertEqual(m.maxTokens, 0)
        let c = try XCTUnwrap(m.capabilities)
        XCTAssertEqual(c.batch?.supported, true)
        XCTAssertEqual(c.contextManagement?.compact20260112?.supported, true)
        XCTAssertEqual(c.contextManagement?.clearThinking20251015?.supported, true)
        XCTAssertEqual(c.contextManagement?.clearToolUses20250919?.supported, true)
        XCTAssertEqual(c.effort?.xhigh?.supported, true)
        XCTAssertEqual(c.effort?.max?.supported, true)
        XCTAssertEqual(c.serverTools?.webSearch?.supported, true)
        XCTAssertEqual(c.serverTools?.codeExecution?.supported, true)
        XCTAssertEqual(c.codeExecution?.supported, true)
        XCTAssertEqual(c.imageInput?.supported, true)
        XCTAssertEqual(c.pdfInput?.supported, true)
        XCTAssertEqual(c.structuredOutputs?.supported, true)
        XCTAssertEqual(c.thinking?.types?.adaptive?.supported, true)
        XCTAssertEqual(c.thinking?.types?.disabled?.supported, true)
        XCTAssertEqual(c.thinking?.types?.enabled?.supported, true)
    }

    func testNullsAndNewValuesDecode() async throws {
        let body = Data(#"""
        {"type":"model","id":"m","display_name":"M","created_at":"1970-01-01T00:00:00Z",
         "capabilities":null,"deprecated_at":null,"retires_at":null,"line":null,
         "lifecycle":"suspended","max_input_tokens":null,"max_tokens":null}
        """#.utf8)
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: body) }
        let m = try await client.models.get(id: "m")
        XCTAssertNil(m.capabilities)
        XCTAssertNil(m.line)
        XCTAssertNil(m.deprecatedAt)
        XCTAssertNil(m.maxTokens)
        XCTAssertEqual(m.lifecycle, "suspended")
    }

    func testLegacyBodyWithoutNewFieldsStillDecodes() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.modelsListLegacy) }
        let page = try await client.models.list()
        XCTAssertEqual(page.data.map(\.id), ["claude-opus-4-5", "claude-sonnet-4-5"])
        XCTAssertNil(page.data[0].capabilities)
        XCTAssertNil(page.data[0].lifecycle)
    }

    func testGetPercentEncodesTheId() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/models/a%2Fb%3Fc")
            return HTTPResponse(statusCode: 200, body: MockResponses.singleModel)
        }
        _ = try await client.models.get(id: "a/b?c")
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
            XCTAssertEqual(request.path, "/v1/models/claude-opus-5")
            return HTTPResponse(statusCode: 200, body: MockResponses.singleModel)
        }
        let model = try await client.models.get(id: "claude-opus-5")
        XCTAssertEqual(model.id, "claude-opus-5")
    }
}
