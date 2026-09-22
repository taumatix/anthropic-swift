import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class SkillsServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    /// Fails the test if a request is sent at all. Used where the point is that validation runs
    /// before the network does — a handler that returns a success body would let a deleted guard
    /// pass silently.
    private func rejectAllRequests(_ message: String = "no request should have been sent") {
        mock.handler = { request in
            XCTFail("\(message) — got \(request.method) \(request.path)")
            return HTTPResponse(statusCode: 500, body: Data())
        }
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
            return HTTPResponse(statusCode: 200, body: MockResponses.skillList)
        }
        _ = try await client.skills.list(limit: 50, pageToken: "page_token_2", source: .custom)
    }

    /// Every `source` maps to the string the API documents, and an unknown one still filters
    /// rather than silently returning everything.
    func testEverySourceFilterIsSentAsItsDocumentedValue() async throws {
        let cases: [(SkillSource.Kind, String)] = [
            (.custom, "custom"),
            (.anthropic, "anthropic"),
            (.anthropicExample, "anthropic_example"),
            (.plugin, "plugin"),
            (.unknown("marketplace"), "marketplace"),
        ]
        for (kind, expected) in cases {
            let mock = MockHTTPClient()
            mock.handler = { request in
                XCTAssertEqual(request.queryItemsByName["source"], expected, "for \(kind)")
                return HTTPResponse(statusCode: 200, body: MockResponses.skillList)
            }
            let client = AnthropicClient(
                configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
            _ = try await client.skills.list(source: kind)
        }
    }

    func testNoSourceFilterIsSentWhenNoneIsAsked() async throws {
        mock.handler = { request in
            XCTAssertNil(request.queryItemsByName["source"])
            return HTTPResponse(statusCode: 200, body: MockResponses.skillList)
        }
        _ = try await client.skills.list()
    }

    /// The beta header bought nothing — the beta document describes the same shape as GA — so the
    /// service no longer sends it.
    func testNoBetaHeaderIsSentByDefault() async throws {
        mock.handler = { request in
            XCTAssertNil(request.headers["anthropic-beta"])
            return HTTPResponse(statusCode: 200, body: MockResponses.skillList)
        }
        _ = try await client.skills.list()
    }

    /// A caller who needs the beta header back has `additionalHeaders`; no Skills-specific API
    /// exists for it.
    func testBetaHeaderCanBeRestoredViaAdditionalHeaders() async throws {
        let mock = MockHTTPClient()
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "skills-2025-10-02")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillList)
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
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.skillList) }
        let page = try await client.skills.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].displayName, "display_name")
        XCTAssertEqual(page.data[0].source?.type, .custom)
        XCTAssertEqual(page.nextPageToken, "next_page")
    }

    func testGetDecodesTheDocumentedSkill() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/skills/skill_01JAbcdefghijklmnopqrstuvw")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillObject)
        }
        let skill = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(skill.latestVersionId, "latest_version_id")
    }

    func testDeleteReturnsTheDeletedSkill() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            XCTAssertEqual(request.path, "/v1/skills/skill_01JAbcdefghijklmnopqrstuvw")
            return HTTPResponse(statusCode: 200, body: MockResponses.skillDeleted)
        }
        let deleted = try await client.skills.delete(id: "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(deleted.type, "skill_deleted")
    }

    /// An id is a path *component*. Unencoded, `../…` would retarget the request to another
    /// endpoint carrying the caller's key.
    func testSkillIdIsPercentEncodedIntoThePath() {
        XCTAssertEqual(SkillsService.skillPath("skill_01"), "/v1/skills/skill_01")
        XCTAssertEqual(SkillsService.skillPath("../organizations/api_keys"),
                       "/v1/skills/..%2Forganizations%2Fapi_keys")
        XCTAssertEqual(SkillsService.skillPath("a b"), "/v1/skills/a%20b")
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
            return HTTPResponse(statusCode: 200, body: MockResponses.skillObject)
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
            return HTTPResponse(statusCode: 200, body: MockResponses.skillObject)
        }
        _ = try await client.skills.create(
            files: [SkillFile(path: "s/SKILL.md", content: Data("x".utf8))])
    }

    func testCreateRejectsAFileSetWithoutASkillManifest() async {
        rejectAllRequests()
        await assertCreateRejects(
            [SkillFile(path: "my-skill/reference.md", content: Data("detail".utf8))],
            because: "SKILL.md")
    }

    /// `hasSuffix("SKILL.md")` would accept this; the last path component must be exactly
    /// `SKILL.md`.
    func testCreateRejectsAFilenameThatMerelyEndsInSkillManifest() async {
        rejectAllRequests()
        await assertCreateRejects(
            [SkillFile(path: "my-skill/MYSKILL.md", content: Data("x".utf8))],
            because: "SKILL.md")
    }

    func testCreateRejectsAnEmptyFileSet() async {
        rejectAllRequests()
        await assertCreateRejects([], because: "at least one file")
    }

    func testCreateRejectsATraversingPath() async {
        rejectAllRequests()
        await assertCreateRejects(
            [SkillFile(path: "../../etc/SKILL.md", content: Data("x".utf8))],
            because: "'..'")
    }

    /// A `SKILL.md` below the top level is the API's call, not ours — it must still be sent.
    func testCreateAllowsANestedManifestAndLetsTheAPIDecide() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.skillObject) }
        _ = try await client.skills.create(
            files: [SkillFile(path: "my-skill/nested/SKILL.md", content: Data("x".utf8))])
        XCTAssertEqual(mock.recordedRequests.count, 1)
    }

    private func assertCreateRejects(
        _ files: [SkillFile],
        because fragment: String,
        line: UInt = #line
    ) async {
        do {
            _ = try await client.skills.create(files: files)
            XCTFail("expected a thrown error", line: line)
        } catch let error as AnthropicError {
            XCTAssertTrue("\(error)".contains(fragment), "\(error)", line: line)
            XCTAssertTrue(error.localizedDescription.contains(fragment),
                          "localizedDescription dropped the reason: \(error.localizedDescription)",
                          line: line)
        } catch {
            XCTFail("unexpected error: \(error)", line: line)
        }
    }

    // MARK: - Backward compatibility

    /// The pre-GA `list(limit:afterId:)` still compiles and still sends `after_id`.
    @available(*, deprecated, message: "exercises deprecated API on purpose")
    func testDeprecatedAfterIdOverloadStillSendsAnIdCursor() async throws {
        mock.handler = { request in
            let items = request.queryItemsByName
            XCTAssertEqual(items["after_id"], "skill_01")
            XCTAssertEqual(items["limit"], "5")
            XCTAssertNil(items["page"])
            return HTTPResponse(statusCode: 200, body: MockResponses.skillList)
        }
        _ = try await client.skills.list(limit: 5, afterId: "skill_01")
    }

    /// The deprecated overload must not iterate: its page is an id-cursor page, and feeding
    /// `lastId` to a `page=` fetcher would re-request the same page forever.
    @available(*, deprecated, message: "exercises deprecated API on purpose")
    func testDeprecatedAfterIdOverloadDoesNotPaginate() async throws {
        let idCursorPage = Data("""
        {"data":[{"id":"skill_01","type":"skill","display_name":"One","created_at":"2025-01-01"}],
         "has_more":true,"first_id":"skill_01","last_id":"skill_01"}
        """.utf8)
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: idCursorPage) }

        var seen = 0
        for try await _ in try await client.skills.list(afterId: nil) { seen += 1 }

        XCTAssertEqual(seen, 1)
        XCTAssertEqual(mock.recordedRequests.count, 1, "must not have re-requested")
    }

    /// The deprecated JSON `create` still POSTs its body, and no longer sends the beta header.
    @available(*, deprecated, message: "exercises deprecated API on purpose")
    func testDeprecatedCreateStillSendsAJSONBody() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/v1/skills")
            XCTAssertNil(request.headers["anthropic-beta"])
            let body = try XCTUnwrap(request.body.map { String(decoding: $0, as: UTF8.self) })
            XCTAssertTrue(body.contains("\"name\":\"My Skill\""), body)
            return HTTPResponse(statusCode: 200, body: MockResponses.skillObject)
        }
        let skill = try await client.skills.create(CreateSkillRequest(name: "My Skill"))
        XCTAssertEqual(skill.displayName, "display_name")
    }

    /// A response carrying the pre-GA `name` key still decodes through the service.
    func testLegacyNameKeyStillDecodesThroughTheService() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: self.legacySkillJSON) }
        let skill = try await client.skills.get(id: "skill_01")
        XCTAssertEqual(skill.displayName, "My Skill")
        XCTAssertEqual(skill.description, "A skill")
    }

    // MARK: - README

    /// The README's Skills example, verbatim enough to compile.
    ///
    /// The fluent-builder example in the same file did not compile for at least two releases —
    /// `ClientOptions()` has no such initializer and `additionalHeader(_:_:)` does not exist.
    /// Nothing was checking, because documentation is not built. This is the check.
    func testTheREADMESkillsExampleCompilesAndRuns() async throws {
        // A single, final page. `MockResponses.skillList` carries `next_page`, and replaying it
        // for every request makes `for try await` iterate forever.
        let finalPage = Data("""
        {"data":[{"id":"skill_01","type":"skill","display_name":"Invoice parser",
          "latest_version_id":"ver_1","source":{"type":"custom"},
          "created_at":"2025-01-01","updated_at":"2025-01-01"}],"next_page":null}
        """.utf8)

        mock.handler = { request in
            switch request.method {
            case "DELETE": return HTTPResponse(statusCode: 200, body: MockResponses.skillDeleted)
            case "POST": return HTTPResponse(statusCode: 200, body: MockResponses.skillObject)
            default: return HTTPResponse(statusCode: 200, body: finalPage)
            }
        }

        let manifest = """
        ---
        name: invoice-parser
        description: Extracts line items from supplier invoices.
        ---

        Read the invoice and return each line item as JSON.
        """

        let skill = try await client.skills.create(
            files: [
                SkillFile(path: "invoice-parser/SKILL.md",
                          content: Data(manifest.utf8),
                          mimeType: "text/markdown")
            ],
            displayName: "Invoice parser"
        )
        _ = (skill.id, skill.displayName, skill.latestVersionId ?? "-")

        for try await listed in try await client.skills.list(source: .custom) {
            _ = (listed.displayName, listed.source?.rawType ?? "unknown")
        }

        let page = try await client.skills.list(limit: 100)
        _ = page.nextPageToken

        try await client.skills.delete(id: skill.id)

        // The round-trip snippet under the Skills section.
        let seen = try await client.skills.list(limit: 1).data.first?.source?.type
        _ = try await client.skills.list(source: seen)
    }

    // MARK: - Pagination

    /// Three pages, so the fetcher that each fetched page carries is actually used. A two-page
    /// test cannot tell a re-attaching fetcher from one that forgets.
    func testIterationFollowsTheNextPageTokenAcrossThreePages() async throws {
        @Sendable func page(_ id: String, next: String?) -> Data {
            let token = next.map { "\"\($0)\"" } ?? "null"
            return Data("""
            {"data":[{"id":"\(id)","type":"skill","display_name":"\(id)","latest_version_id":"v1",
              "source":{"type":"custom"},"created_at":"2025-01-01","updated_at":"2025-01-01"}],
             "next_page":\(token)}
            """.utf8)
        }

        mock.handler = { request in
            switch request.queryItemsByName["page"] {
            case nil: return HTTPResponse(statusCode: 200, body: page("skill_01", next: "token_2"))
            case "token_2": return HTTPResponse(statusCode: 200, body: page("skill_02", next: "token_3"))
            case "token_3": return HTTPResponse(statusCode: 200, body: page("skill_03", next: nil))
            case let other:
                XCTFail("unexpected page token: \(other ?? "nil")")
                return HTTPResponse(statusCode: 500, body: Data())
            }
        }

        var ids: [String] = []
        for try await skill in try await client.skills.list(limit: 1, source: .custom) {
            ids.append(skill.id)
        }

        XCTAssertEqual(ids, ["skill_01", "skill_02", "skill_03"])
        XCTAssertEqual(mock.recordedRequests.count, 3)
        XCTAssertEqual(mock.recordedRequests.map { $0.queryItemsByName["page"] },
                       [nil, "token_2", "token_3"])
        // limit and source must survive every boundary, not just the first.
        XCTAssertEqual(mock.recordedRequests.map { $0.queryItemsByName["limit"] },
                       ["1", "1", "1"])
        XCTAssertEqual(mock.recordedRequests.map { $0.queryItemsByName["source"] },
                       ["custom", "custom", "custom"])
    }

    /// An empty page that still carries a token must not end the sequence.
    func testIterationSkipsAnEmptyIntermediatePage() async throws {
        let first = Data("""
        {"data":[{"id":"skill_01","type":"skill","display_name":"One","created_at":"2025-01-01"}],
         "next_page":"token_2"}
        """.utf8)
        let empty = Data("""
        {"data":[],"next_page":"token_3"}
        """.utf8)
        let last = Data("""
        {"data":[{"id":"skill_03","type":"skill","display_name":"Three","created_at":"2025-01-01"}],
         "next_page":null}
        """.utf8)

        mock.handler = { request in
            switch request.queryItemsByName["page"] {
            case nil: return HTTPResponse(statusCode: 200, body: first)
            case "token_2": return HTTPResponse(statusCode: 200, body: empty)
            default: return HTTPResponse(statusCode: 200, body: last)
            }
        }

        var ids: [String] = []
        for try await skill in try await client.skills.list() { ids.append(skill.id) }
        XCTAssertEqual(ids, ["skill_01", "skill_03"])
    }
}
