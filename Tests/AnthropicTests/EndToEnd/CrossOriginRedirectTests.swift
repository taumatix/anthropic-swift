#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// A redirect must not take the caller's traffic to a host they never named.
///
/// `URLSession` follows redirects itself and replays the original request onto the target,
/// stripping nothing. The first fix removed credential headers and let the redirect proceed; a
/// security review showed that was not enough, and these tests encode all three reasons:
///
/// - 307/308 preserve method and body, so the foreign origin got the prompt and the uploaded file.
/// - Nothing re-checks where a response came from, so the foreign origin's body was decoded and
///   returned as the API's answer.
/// - `BaseURLPolicy` validates `baseURL` once, so a redirect was the way to reach `http://` from
///   an `https://` base.
///
/// Two loopback servers on different ports make it observable without leaving the host.
final class CrossOriginRedirectTests: XCTestCase {

    private var origin: LoopbackHTTPServer?
    private var elsewhere: LoopbackHTTPServer?

    override func tearDown() {
        origin?.stop(); elsewhere?.stop()
        origin = nil; elsewhere = nil
        super.tearDown()
    }

    // MARK: - Cross-origin is refused

    func testACrossOriginRedirectIsNotFollowed() async throws {
        let client = try await startClientRedirectingElsewhere(status: 302)

        do {
            _ = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")
            XCTFail("a cross-origin redirect should not have been followed")
        } catch AnthropicError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 302, "the caller should see the hop, not a stranger's reply")
        }

        // The companion to "elsewhere saw nothing": the request definitely happened, and the
        // origin definitely redirected. Without this, deleting the transport would pass.
        XCTAssertEqual(origin?.receivedRequests.count, 1, "the request never reached the origin")
        XCTAssertEqual(elsewhere?.receivedRequests.count, 0,
                       "the foreign origin was contacted: \(elsewhere?.receivedRequests.first?.headers ?? [:])")
    }

    func testEveryRedirectStatusIsRefused() async throws {
        for status in [301, 302, 307, 308] {
            let client = try await startClientRedirectingElsewhere(status: status)

            _ = try? await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

            XCTAssertEqual(origin?.receivedRequests.count, 1, "HTTP \(status): origin not reached")
            XCTAssertEqual(elsewhere?.receivedRequests.count, 0,
                           "HTTP \(status) was followed to the foreign origin")

            origin?.stop(); elsewhere?.stop()
        }
    }

    /// 308 preserves the method and body. This is the finding that made stripping headers
    /// insufficient: the credential was protected and the conversation was handed over instead.
    func testThePromptDoesNotCrossOnABodyPreservingRedirect() async throws {
        let client = try await startClientRedirectingElsewhere(status: 308)

        _ = try? await client.messages.create(
            MessageRequest(model: .claudeSonnet5,
                           messages: [.user("MY-CONFIDENTIAL-PROMPT")],
                           maxTokens: 16)
        )

        let sentToOrigin = String(decoding: origin?.receivedRequests.first?.body ?? Data(), as: UTF8.self)
        XCTAssertTrue(sentToOrigin.contains("MY-CONFIDENTIAL-PROMPT"),
                      "the prompt never reached the origin, so this proves nothing about the hop")
        XCTAssertEqual(elsewhere?.receivedRequests.count, 0, "the prompt crossed to a foreign origin")
    }

    /// The upload path frames a multipart body carrying file contents, so it is the worst case.
    func testAnUploadedFileDoesNotCrossOnABodyPreservingRedirect() async throws {
        let client = try await startClientRedirectingElsewhere(status: 308)

        _ = try? await client.skills.create(
            files: [SkillFile(path: "my-skill/SKILL.md", content: Data("SECRET-FILE-BYTES".utf8))]
        )

        let sentToOrigin = String(decoding: origin?.receivedRequests.first?.body ?? Data(), as: UTF8.self)
        XCTAssertTrue(sentToOrigin.contains("SECRET-FILE-BYTES"),
                      "the file never reached the origin, so this proves nothing about the hop")
        XCTAssertEqual(elsewhere?.receivedRequests.count, 0, "file contents crossed to a foreign origin")
    }

    /// Streaming builds its request on a separate path — the split that let the original leak sit
    /// in `bytes(for:)` after `data(for:)` was guarded.
    func testAStreamingRequestDoesNotCrossOrigins() async throws {
        let client = try await startClientRedirectingElsewhere(status: 307)

        let stream = client.messages.stream(
            MessageRequest(model: .claudeSonnet5,
                           messages: [.user("MY-CONFIDENTIAL-PROMPT")],
                           maxTokens: 16)
        )
        do {
            for try await _ in stream {}
        } catch {}

        XCTAssertEqual(origin?.receivedRequests.count, 1, "the stream never opened")
        XCTAssertEqual(elsewhere?.receivedRequests.count, 0, "the stream crossed to a foreign origin")
    }

    /// The second critical finding: even with credentials stripped, a followed redirect let the
    /// foreign origin's body decode into a `MessageResponse` the caller would act on.
    func testAForeignOriginCannotForgeTheResponse() async throws {
        let elsewhere = try LoopbackHTTPServer { _ in .json(200, Self.forgedMessage) }
        self.elsewhere = elsewhere
        let elsewhereURL = try await elsewhere.start()

        let origin = try LoopbackHTTPServer { _ in
            .redirect(302, to: elsewhereURL.appendingPathComponent("v1/messages"))
        }
        self.origin = origin
        let originURL = try await origin.start()

        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(originURL).maxRetries(0)
        )

        do {
            let response = try await client.messages.create(
                MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
            )
            XCTFail("a forged response was returned to the caller as the API's answer: \(response.id)")
        } catch AnthropicError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 302)
        }
    }

    /// Proves the forgery fixture would actually decode if it were delivered — otherwise the test
    /// above could pass because the body was unusable rather than because it never arrived.
    func testTheForgedFixtureWouldOtherwiseDecode() async throws {
        let server = try LoopbackHTTPServer { _ in .json(200, Self.forgedMessage) }
        self.origin = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0)
        )

        let response = try await client.messages.create(
            MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
        )

        XCTAssertEqual(response.id, "msg_forged")
    }

    // MARK: - Same origin still works

    /// The companion to every refusal above: a server moving a path is entitled to the credentials
    /// the caller sent it, and refusing there would break every legitimate redirect.
    func testASameOriginRedirectIsFollowedAndKeepsTheAPIKey() async throws {
        let server = try LoopbackHTTPServer { request in
            request.path.hasSuffix("/moved")
                ? .json(200, MockResponses.skillObject)
                : .redirect(302, to: URL(string: "/v1/skills/moved")!)
        }
        self.origin = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "configuration-key",
            options: ClientOptions(apiKey: "options-key").baseURL(baseURL).maxRetries(0)
        )

        let skill = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

        XCTAssertEqual(skill.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(server.receivedRequests.count, 2, "the redirect was not followed")
        let followed = try XCTUnwrap(server.receivedRequests.last)
        XCTAssertTrue(followed.path.hasSuffix("/moved"))
        // Distinct literals: `AnthropicClient.init(apiKey:options:)` overwrites the options' key,
        // so identical ones could not show which reached the wire.
        XCTAssertEqual(followed.headers["x-api-key"], "configuration-key")
        XCTAssertNotNil(followed.headers["anthropic-version"],
                        "a same-origin redirect must keep the version header too")
    }

    /// Several same-origin hops in a row must all be followed — the guard compares against the
    /// original request, and a bug there would show up on hop three rather than hop two.
    func testAChainOfSameOriginRedirectsIsFollowed() async throws {
        let server = try LoopbackHTTPServer { request in
            if request.path.hasSuffix("/third") { return .json(200, MockResponses.skillObject) }
            if request.path.hasSuffix("/second") { return .redirect(302, to: URL(string: "/v1/skills/third")!) }
            return .redirect(302, to: URL(string: "/v1/skills/second")!)
        }
        self.origin = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0)
        )

        let skill = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

        XCTAssertEqual(skill.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(server.receivedRequests.count, 3)
        XCTAssertEqual(server.receivedRequests.last?.headers["x-api-key"], "test-key")
    }

    // MARK: - Setup

    private static let forgedMessage = Data("""
    {"id":"msg_forged","type":"message","role":"assistant","model":"claude-sonnet-5",
     "content":[{"type":"text","text":"ATTACKER CONTROLLED"}],"stop_reason":"end_turn",
     "stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}
    """.utf8)

    /// Starts two loopback servers: one that redirects to the other. They differ by port, so the
    /// redirect crosses an origin.
    private func startClientRedirectingElsewhere(status: Int) async throws -> AnthropicClient {
        let elsewhere = try LoopbackHTTPServer { _ in .json(200, MockResponses.skillObject) }
        self.elsewhere = elsewhere
        let elsewhereURL = try await elsewhere.start()

        let origin = try LoopbackHTTPServer { _ in
            .redirect(status, to: elsewhereURL.appendingPathComponent("v1/harvested"))
        }
        self.origin = origin
        let originURL = try await origin.start()

        return AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(originURL).maxRetries(0)
        )
    }
}
#endif
