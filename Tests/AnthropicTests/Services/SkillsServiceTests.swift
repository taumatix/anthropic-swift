import XCTest
@testable import Anthropic
import AnthropicTestSupport

extension HTTPRequest {
    /// Query parameters keyed by name, dropping any without a value.
    var queryItemsByName: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }
}

final class SkillsServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    /// The pre-GA body this SDK's fixtures used to assert. Kept to prove the fallback path, not
    /// because the API returns it.
    let legacySkillJSON = Data("""
    {"id":"skill_01","type":"skill","name":"My Skill","description":"A skill","created_at":"2025-01-01"}
    """.utf8)

    // MARK: - Request shape

    func testListRequestsTheDocumentedQueryParameters() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/v1/skills")
            let items = request.queryItemsByName
            XCTAssertEqual(items["limit"], "50")
            XCTAssertEqual(items["page"], "page_token_2")
            XCTAssertEqual(items["source"], "custom")
            XCTAssertNil(items["after_id"], "the Skills API paginates by token, not by id")
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillListJSON)
        }
        _ = try await client.skills.list(limit: 50, page: "page_token_2", source: .custom)
    }

    /// The beta header bought nothing — the beta document describes the same shape as GA — so the
    /// service no longer sends it.
    func testNoBetaHeaderIsSentByDefault() async throws {
        mock.handler = { request in
            XCTAssertNil(request.headers["anthropic-beta"])
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillListJSON)
        }
        _ = try await client.skills.list()
    }

    /// A caller who needs the beta header back has `additionalHeaders`; no Skills-specific API
    /// exists for it.
    func testBetaHeaderCanBeRestoredViaAdditionalHeaders() async throws {
        let mock = MockHTTPClient()
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "skills-2025-10-02")
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillListJSON)
        }
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key")
                .httpClient(mock)
                .additionalHeaders(["anthropic-beta": "skills-2025-10-02"])
        )
        _ = try await client.skills.list()
    }

    // MARK: - Responses

    func testListDecodesTheDocumentedEnvelope() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillListJSON) }
        let page = try await client.skills.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].displayName, "display_name")
        XCTAssertEqual(page.data[0].source?.type, .custom)
        XCTAssertEqual(page.nextPage, "next_page")
    }

    func testGetDecodesTheDocumentedSkill() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/skills/skill_01JAbcdefghijklmnopqrstuvw")
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillObjectJSON)
        }
        let skill = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(skill.latestVersionId, "latest_version_id")
    }

    func testDeleteReturnsTheDeletedSkill() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            XCTAssertEqual(request.path, "/v1/skills/skill_01")
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.deletedSkillJSON)
        }
        let deleted = try await client.skills.delete(id: "skill_01")
        XCTAssertEqual(deleted.type, "skill_deleted")
    }

    // MARK: - Create

    /// `POST /v1/skills` is `multipart/form-data` with a `files[]` part per file — see
    /// <https://platform.claude.com/docs/en/api/skills/create> (retrieved 2026-09-22).
    func testCreateUploadsFilesAsMultipart() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/v1/skills")
            let contentType = try XCTUnwrap(request.headers["content-type"])
            XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="), contentType)

            let body = try XCTUnwrap(request.body.map { String(decoding: $0, as: UTF8.self) })
            XCTAssertTrue(body.contains("name=\"files[]\"; filename=\"my-skill/SKILL.md\""), body)
            XCTAssertTrue(body.contains("---\nname: my-skill\n---"), body)
            XCTAssertTrue(body.contains("name=\"files[]\"; filename=\"my-skill/reference.md\""), body)
            XCTAssertTrue(body.contains("name=\"display_name\""), body)
            XCTAssertTrue(body.contains("My Skill"), body)
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillObjectJSON)
        }

        let skill = try await client.skills.create(
            files: [
                SkillFile(path: "my-skill/SKILL.md", content: Data("---\nname: my-skill\n---".utf8)),
                SkillFile(path: "my-skill/reference.md", content: Data("detail".utf8)),
            ],
            displayName: "My Skill"
        )
        XCTAssertEqual(skill.displayName, "display_name")
    }

    /// `display_name` is optional — the API derives it from the SKILL.md frontmatter when omitted.
    func testCreateOmitsDisplayNameWhenNotGiven() async throws {
        mock.handler = { request in
            let body = try XCTUnwrap(request.body.map { String(decoding: $0, as: UTF8.self) })
            XCTAssertFalse(body.contains("name=\"display_name\""), body)
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillObjectJSON)
        }
        _ = try await client.skills.create(
            files: [SkillFile(path: "s/SKILL.md", content: Data("x".utf8))])
    }

    func testCreateRejectsAFileSetWithoutASkillManifest() async {
        mock.handler = { _ in
            XCTFail("the request must not be sent")
            return HTTPResponse(statusCode: 200, body: Data())
        }
        do {
            _ = try await client.skills.create(
                files: [SkillFile(path: "my-skill/reference.md", content: Data("detail".utf8))])
            XCTFail("expected a thrown error")
        } catch let error as AnthropicError {
            XCTAssertTrue("\(error)".contains("SKILL.md"), "\(error)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCreateRejectsAnEmptyFileSet() async {
        do {
            _ = try await client.skills.create(files: [])
            XCTFail("expected a thrown error")
        } catch is AnthropicError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Backward compatibility

    /// The pre-GA `list(limit:afterId:)` still compiles and still sends `after_id`.
    @available(*, deprecated, message: "exercises deprecated API on purpose")
    func testDeprecatedAfterIdOverloadStillSendsAnIdCursor() async throws {
        mock.handler = { request in
            let items = request.queryItemsByName
            XCTAssertEqual(items["after_id"], "skill_01")
            return HTTPResponse(statusCode: 200, body: SkillDecodingTests.skillListJSON)
        }
        _ = try await client.skills.list(afterId: "skill_01")
    }

    /// `skill.name` is deprecated but must keep compiling and returning the label.
    func testDeprecatedNameStillReadsTheLabel() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: self.legacySkillJSON) }
        let skill = try await client.skills.get(id: "skill_01")
        XCTAssertEqual(skill.displayName, "My Skill")
        XCTAssertEqual(skill.description, "A skill")
    }

    // MARK: - Pagination

    /// `Page` is an `AsyncSequence`; iterating past the first page must follow `next_page`.
    func testIterationFollowsTheNextPageToken() async throws {
        let firstPage = Data("""
        {"data":[{"id":"skill_01","type":"skill","display_name":"One","latest_version_id":"v1",
          "source":{"type":"custom"},"created_at":"2025-01-01","updated_at":"2025-01-01"}],
         "next_page":"token_2"}
        """.utf8)
        let lastPage = Data("""
        {"data":[{"id":"skill_02","type":"skill","display_name":"Two","latest_version_id":"v1",
          "source":{"type":"anthropic"},"created_at":"2025-01-02","updated_at":"2025-01-02"}],
         "next_page":null}
        """.utf8)

        mock.handler = { request in
            let page = request.queryItemsByName["page"]
            switch page {
            case nil: return HTTPResponse(statusCode: 200, body: firstPage)
            case "token_2": return HTTPResponse(statusCode: 200, body: lastPage)
            default:
                XCTFail("unexpected page token: \(page ?? "nil")")
                return HTTPResponse(statusCode: 200, body: lastPage)
            }
        }

        var ids: [String] = []
        for try await skill in try await client.skills.list() {
            ids.append(skill.id)
        }
        XCTAssertEqual(ids, ["skill_01", "skill_02"])
    }
}
