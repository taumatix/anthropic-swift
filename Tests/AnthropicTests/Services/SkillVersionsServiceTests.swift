import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class SkillVersionsServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testGetLatestRequestsTheLiteralLatest() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/v1/skills/skill_01/versions/latest")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionObject)
        }
        let version = try await client.skills.versions.get(skillID: "skill_01", version: .latest)
        XCTAssertEqual(version.skillId, "skill_01JAbcdefghijklmnopqrstuvw")
    }

    func testGetByIDRequestsThatVersion() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/skills/skill_01/versions/ver_9")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionObject)
        }
        _ = try await client.skills.versions.get(skillID: "skill_01", version: .id("ver_9"))
    }

    /// An id that carries a path separator must stay inside its segment, or it retargets the
    /// request — with the caller's key — at another endpoint.
    func testIdentifiersCannotEscapeTheirPathSegment() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/skills/..%2Forganizations/versions/..%2Fapi_keys")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionObject)
        }
        _ = try await client.skills.versions.get(skillID: "../organizations", version: .id("../api_keys"))
    }

    func testListSendsTheDocumentedQueryParameters() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/v1/skills/skill_01/versions")
            XCTAssertEqual(request.queryItemsByName["limit"], "50")
            XCTAssertEqual(request.queryItemsByName["page"], "tok_2")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionList)
        }
        _ = try await client.skills.versions.list(skillID: "skill_01", limit: 50, pageToken: "tok_2")
    }

    func testIteratingFollowsTheTokenAndKeepsTheLimit() async throws {
        let first = Data(#"{"data":[{"id":"v1","skill_id":"s","created_at":"c"}],"next_page":"tok_2"}"#.utf8)
        let second = Data(#"{"data":[{"id":"v2","skill_id":"s","created_at":"c"}],"next_page":null}"#.utf8)
        mock.handler = { request in
            HTTPResponse(statusCode: 200, body: request.queryItemsByName["page"] == "tok_2" ? second : first)
        }

        var ids: [String] = []
        for try await version in try await client.skills.versions.list(skillID: "s", limit: 1) {
            ids.append(version.id)
        }

        XCTAssertEqual(ids, ["v1", "v2"])
        XCTAssertEqual(mock.recordedRequests.count, 2)
        XCTAssertEqual(mock.recordedRequests[1].queryItemsByName["limit"], "1", "limit must survive the page boundary")
    }
}

final class SkillVersionsWriteTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    private let files = [SkillFile(path: "my-skill/SKILL.md", content: Data("---\nname: my-skill\n---\n".utf8), mimeType: "text/markdown")]

    func testCreatePostsMultipartToTheVersionsPath() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/v1/skills/skill_01/versions")
            XCTAssertTrue(request.headers["content-type"]?.hasPrefix("multipart/form-data; boundary=") == true)
            let body = String(decoding: request.body ?? Data(), as: UTF8.self)
            XCTAssertTrue(body.contains("name=\"files[]\"; filename=\"my-skill/SKILL.md\""), body)
            XCTAssertFalse(body.contains("display_name"), body)
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionObject)
        }
        let version = try await client.skills.versions.create(skillID: "skill_01", files: files)
        XCTAssertEqual(version.type, "skill_version")
    }

    func testCreateWithoutASkillMdSendsNothing() async throws {
        mock.handler = { _ in XCTFail("no request should be sent"); return HTTPResponse(statusCode: 200, body: Data()) }
        do {
            _ = try await client.skills.versions.create(
                skillID: "skill_01", files: [SkillFile(path: "my-skill/other.md", content: Data())])
            XCTFail("expected an error")
        } catch AnthropicError.encodingError {}
    }

    func testDeleteSendsDELETEAndDecodesTheDocumentedBody() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            XCTAssertEqual(request.path, "/v1/skills/skill_01/versions/ver_9")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionDeleted)
        }
        let deleted = try await client.skills.versions.delete(skillID: "skill_01", version: "ver_9")
        XCTAssertEqual(deleted, DeletedSkillVersion(id: "id", type: "skill_version_deleted"))
    }

    func testDeleteEncodesTheVersionSegment() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/skills/skill_01/versions/..%2Fx")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillVersionDeleted)
        }
        _ = try await client.skills.versions.delete(skillID: "skill_01", version: "../x")
    }
}
