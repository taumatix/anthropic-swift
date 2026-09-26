#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// End-to-end tests for the Skills API: a real `AnthropicClient` with its real
/// `URLSessionHTTPClient`, over a real TCP socket, against a server replaying the response bodies
/// Anthropic publishes.
///
/// These exist because the service tests inject a `MockHTTPClient` and therefore prove nothing
/// about URL construction, header injection, multipart framing or the HTTP layer. The fixtures are
/// the documented `Response (200)` bodies, so the test can disagree with the implementation.
///
/// What they do *not* prove is that Anthropic still returns these bodies. `LiveSkillsTests` covers
/// that and needs a key.
final class SkillsEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    private func startClient(
        responder: @escaping LoopbackHTTPServer.Responder
    ) async throws -> AnthropicClient {
        let server = try LoopbackHTTPServer(responder: responder)
        self.server = server
        let baseURL = try await server.start()
        return AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0)
        )
    }

    // MARK: - List

    func testListDecodesTheDocumentedBodyOverARealSocket() async throws {
        let client = try await startClient { _ in
            .json(200, MockResponses.skillList)
        }

        let page = try await client.skills.list(limit: 2, source: .custom)

        XCTAssertEqual(page.data.count, 1)
        let skill = try XCTUnwrap(page.data.first)
        XCTAssertEqual(skill.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(skill.displayName, "display_name")
        XCTAssertEqual(skill.latestVersionId, "latest_version_id")
        XCTAssertEqual(skill.source?.type, .custom)
        XCTAssertEqual(page.nextPageToken, "next_page")

        let request = try XCTUnwrap(server.receivedRequests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/v1/skills")
        XCTAssertEqual(request.query["limit"], "2")
        XCTAssertEqual(request.query["source"], "custom")
        XCTAssertEqual(request.headers["x-api-key"], "test-key")
        XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")
        XCTAssertNil(request.headers["anthropic-beta"])
    }

    /// Consuming the `AsyncSequence` past the first page must issue a second request carrying the
    /// `next_page` token as `page`, and must keep the `source` filter on it.
    func testIteratingPagesFollowsTheTokenOverARealSocket() async throws {
        let first = Data("""
        {"data":[{"id":"skill_01","type":"skill","display_name":"One","latest_version_id":"ver_1",
          "source":{"type":"custom"},"created_at":"2025-01-01T00:00:00Z",
          "updated_at":"2025-01-01T00:00:00Z"}],"next_page":"token_2"}
        """.utf8)
        let second = Data("""
        {"data":[{"id":"skill_02","type":"skill","display_name":"Two","latest_version_id":"ver_2",
          "source":{"type":"plugin"},"created_at":"2025-01-02T00:00:00Z",
          "updated_at":"2025-01-02T00:00:00Z"}],"next_page":null}
        """.utf8)

        let client = try await startClient { request in
            request.query["page"] == "token_2" ? .json(200, second) : .json(200, first)
        }

        var collected: [String] = []
        for try await skill in try await client.skills.list(source: .custom) {
            collected.append(skill.displayName)
        }

        XCTAssertEqual(collected, ["One", "Two"])
        XCTAssertEqual(server.receivedRequests.count, 2)
        XCTAssertNil(server.receivedRequests[0].query["page"])
        XCTAssertEqual(server.receivedRequests[1].query["page"], "token_2")
        XCTAssertEqual(server.receivedRequests[1].query["source"], "custom",
                       "the filter must survive the page boundary")
    }

    // MARK: - Create

    func testCreateSendsAMultipartFileSetOverARealSocket() async throws {
        let client = try await startClient { _ in
            .json(200, MockResponses.skillObject)
        }

        let manifest = Data("---\nname: my-skill\ndescription: does a thing\n---\n".utf8)
        let skill = try await client.skills.create(
            files: [
                SkillFile(path: "my-skill/SKILL.md", content: manifest, mimeType: "text/markdown"),
                SkillFile(path: "my-skill/reference.md", content: Data("detail\n".utf8)),
            ],
            displayName: "My Skill"
        )
        XCTAssertEqual(skill.displayName, "display_name")

        let request = try XCTUnwrap(server.receivedRequests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/v1/skills")

        let contentType = try XCTUnwrap(request.headers["content-type"])
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="), contentType)

        // The body that actually crossed the socket, framed by Content-Length.
        let body = String(decoding: request.body, as: UTF8.self)
        XCTAssertEqual(request.body.count, Int(request.headers["content-length"] ?? "-1"))
        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"files[]\"; filename=\"my-skill/SKILL.md\""), body)
        XCTAssertTrue(body.contains("Content-Type: text/markdown"), body)
        XCTAssertTrue(body.contains("description: does a thing"), body)
        XCTAssertTrue(body.contains("filename=\"my-skill/reference.md\""), body)
        XCTAssertTrue(body.contains("name=\"display_name\""), body)
    }

    /// A file set with no `SKILL.md` must be rejected before anything reaches the network.
    func testInvalidFileSetNeverReachesTheSocket() async throws {
        let client = try await startClient { _ in .json(200, MockResponses.skillObject) }

        do {
            _ = try await client.skills.create(
                files: [SkillFile(path: "my-skill/reference.md", content: Data("detail".utf8))])
            XCTFail("expected a thrown error")
        } catch is AnthropicError {
            XCTAssertTrue(server.receivedRequests.isEmpty, "no request should have been sent")
        }
    }

    // MARK: - Get and delete

    func testGetAndDeleteOverARealSocket() async throws {
        let client = try await startClient { request in
            request.method == "DELETE"
                ? .json(200, MockResponses.skillDeleted)
                : .json(200, MockResponses.skillObject)
        }

        let skill = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(skill.latestVersionId, "latest_version_id")

        let deleted = try await client.skills.delete(id: "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(deleted.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(deleted.type, "skill_deleted")

        XCTAssertEqual(server.receivedRequests.map(\.path), [
            "/v1/skills/skill_01JAbcdefghijklmnopqrstuvw",
            "/v1/skills/skill_01JAbcdefghijklmnopqrstuvw",
        ])
        XCTAssertEqual(server.receivedRequests.map(\.method), ["GET", "DELETE"])
    }

    // MARK: - Routing

    /// `BaseURLRoutingTests` proves the client object was rebuilt. This proves a request actually
    /// arrives there, and covers the mutate-after-construction path specifically.
    func testMutatingBaseURLAfterConstructionRoutesToTheNewHost() async throws {
        let server = try LoopbackHTTPServer { _ in .json(200, MockResponses.skillList) }
        self.server = server
        let baseURL = try await server.start()

        var configuration = ClientConfiguration(apiKey: "test-key")
        XCTAssertEqual(configuration.baseURL, ClientConfiguration.defaultBaseURL)
        configuration.baseURL = baseURL
        configuration.maxRetries = 0

        let page = try await AnthropicClient(configuration: configuration).skills.list()

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(server.receivedRequests.count, 1,
                       "the request must have reached the loopback server, not api.anthropic.com")
    }

    /// Injecting a client is the only way to supply a custom `URLSession`; doing so must not cost
    /// the caller the ability to set `baseURL`.
    func testAnInjectedURLSessionClientIsStillRetargeted() async throws {
        let server = try LoopbackHTTPServer { _ in .json(200, MockResponses.skillList) }
        self.server = server
        let baseURL = try await server.start()

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        let injected = URLSessionHTTPClient(session: URLSession(configuration: sessionConfiguration))

        var configuration = ClientConfiguration(apiKey: "test-key", httpClient: injected)
        configuration.baseURL = baseURL
        configuration.maxRetries = 0

        _ = try await AnthropicClient(configuration: configuration).skills.list()
        XCTAssertEqual(server.receivedRequests.count, 1)
    }

    // MARK: - Multipart framing

    /// A filename is caller-supplied. Unescaped, a `"` or CRLF in it would close the quoted
    /// parameter and forge further part headers.
    func testAFilenameCannotForgePartHeaders() async throws {
        let client = try await startClient { _ in .json(200, MockResponses.skillObject) }

        let hostile = "a\";name=\"display_name\"\r\nX-Injected: yes\r\n\r\npwned\r\n--x--/SKILL.md"
        _ = try await client.skills.create(
            files: [SkillFile(path: hostile, content: Data("x".utf8))])

        let request = try XCTUnwrap(server.receivedRequests.first)
        let body = String(decoding: request.body, as: UTF8.self)

        // The hostile text may survive as literal characters inside the quoted filename — that is
        // harmless. What must not survive is its framing: a CRLF that starts a new header line,
        // and an unescaped quote that closes the parameter.
        XCTAssertFalse(body.contains("\r\nX-Injected"), "a forged header line was framed:\n\(body)")
        XCTAssertFalse(body.contains("\r\n\r\npwned"), "a forged part body was framed:\n\(body)")
        XCTAssertTrue(body.contains("\\\""), "the quote should have been backslash-escaped")
        // One file part, one Content-Disposition. Forgery would produce a second.
        XCTAssertEqual(body.components(separatedBy: "Content-Disposition:").count - 1, 1, body)
        XCTAssertFalse(body.contains("name=\"display_name\""),
                       "the filename forged a second form field:\n\(body)")
    }

    // MARK: - Errors

    /// A 401 must surface as `authenticationFailed`, not as a decoding failure on the error body.
    func testAuthenticationFailureSurfacesOverARealSocket() async throws {
        let errorBody = Data("""
        {"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}
        """.utf8)
        let client = try await startClient { _ in .json(401, errorBody) }

        do {
            _ = try await client.skills.list()
            XCTFail("expected a thrown error")
        } catch let error as AnthropicError {
            XCTAssertEqual("\(error)", "AnthropicError.authenticationFailed")
        }
    }
}
#endif
