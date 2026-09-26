#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// A redirect must not carry the API key to a host the caller never named.
///
/// `URLSession` follows redirects by itself and replays the original request's headers onto the
/// target, including custom ones — it strips nothing, not even across an origin change. Since the
/// SDK authenticates with an `x-api-key` header, anything that can answer with a `302` can harvest
/// the caller's key: a gateway they configured, a compromised one, or a plaintext endpoint someone
/// else can answer on.
///
/// Two servers on 127.0.0.1 make this observable without leaving the host. They differ by port,
/// which is an origin change, so a guard keyed on the origin has to strip.
final class RedirectCredentialTests: XCTestCase {

    private var origin: LoopbackHTTPServer?
    private var elsewhere: LoopbackHTTPServer?

    override func tearDown() {
        origin?.stop()
        elsewhere?.stop()
        origin = nil
        elsewhere = nil
        super.tearDown()
    }

    /// Headers that must never survive a redirect to another origin.
    private static let credentialHeaders = ["x-api-key", "authorization"]

    // MARK: - Cross-origin

    /// The one this entry exists for: a second listener must never see the key.
    func testACrossOriginRedirectDoesNotCarryTheAPIKey() async throws {
        let client = try await startClientRedirectingElsewhere(status: 302)

        // Whether the call succeeds is beside the point; what the second server saw is the point.
        _ = try? await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

        let leaked = try XCTUnwrap(elsewhere?.receivedRequests.first,
                                  "the redirect was not followed, so this test proves nothing about what a "
                                  + "followed one carries — check the Location header the origin sent")
        for header in Self.credentialHeaders {
            XCTAssertNil(leaked.headers[header],
                         "\(header) reached a host the caller never named: \(leaked.headers)")
        }
    }

    /// The `anthropic-*` family carries beta opt-ins and, for admin calls, routing the caller did
    /// not intend to publish. Same rule.
    func testACrossOriginRedirectDoesNotCarryAnthropicHeaders() async throws {
        let client = try await startClientRedirectingElsewhere(status: 302)

        _ = try? await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

        let leaked = try XCTUnwrap(elsewhere?.receivedRequests.first)
        let anthropicHeaders = leaked.headers.keys.filter { $0.hasPrefix("anthropic-") }
        XCTAssertTrue(anthropicHeaders.isEmpty,
                      "anthropic-* headers reached another origin: \(anthropicHeaders)")
    }

    /// 307 and 308 preserve the method and body, so they are the shapes that also replay the
    /// prompt. Covered explicitly because a guard written against 302 alone would pass above.
    func testCredentialsAreStrippedOnEveryRedirectStatus() async throws {
        for status in [301, 302, 307, 308] {
            let client = try await startClientRedirectingElsewhere(status: status)

            _ = try? await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

            let leaked = try XCTUnwrap(elsewhere?.receivedRequests.first,
                                       "HTTP \(status) was not followed")
            XCTAssertNil(leaked.headers["x-api-key"], "x-api-key leaked on HTTP \(status)")

            origin?.stop()
            elsewhere?.stop()
        }
    }

    /// Streaming goes through `URLSession.bytes(for:)`, a different call than `data(for:)`. A guard
    /// installed on only one of them leaves the other leaking, and the streaming path is the one
    /// carrying the conversation.
    func testAStreamingRequestDoesNotCarryTheAPIKeyAcrossOrigins() async throws {
        let client = try await startClientRedirectingElsewhere(status: 302)

        let stream = client.messages.stream(
            MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
        )
        // `MessageStream` is lazy — iterating is what opens the connection. The redirect target
        // replies with JSON, not SSE, so an error here is expected and not what is under test.
        do {
            for try await _ in stream {}
        } catch {}

        let leaked = try XCTUnwrap(elsewhere?.receivedRequests.first,
                                   "the streaming redirect was not followed")
        XCTAssertNil(leaked.headers["x-api-key"], "x-api-key leaked from the streaming path")
    }

    // MARK: - Same origin

    /// The guard must not break a legitimate redirect. A server moving `/v1/skills/x` to
    /// `/v1/skills/y` on the same origin is entitled to the key, and stripping there would turn a
    /// working call into a 401 — so this is the companion that proves the header was ever present.
    func testASameOriginRedirectKeepsTheAPIKey() async throws {
        let server = try LoopbackHTTPServer { request in
            request.path.hasSuffix("/moved")
                ? .json(200, MockResponses.skillObject)
                : .redirect(302, to: URL(string: "/v1/skills/moved", relativeTo: nil)!)
        }
        self.origin = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0)
        )

        let skill = try await client.skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

        XCTAssertEqual(skill.id, "skill_01JAbcdefghijklmnopqrstuvw",
                       "a same-origin redirect must still complete")
        let followed = try XCTUnwrap(server.receivedRequests.last)
        XCTAssertTrue(followed.path.hasSuffix("/moved"), "the redirect was not followed")
        XCTAssertEqual(followed.headers["x-api-key"], "test-key",
                       "a same-origin redirect must keep the key, or every legitimate redirect 401s")
    }

    // MARK: - Setup

    /// Starts two loopback servers: one that redirects to the other. They differ by port, so the
    /// redirect crosses an origin.
    private func startClientRedirectingElsewhere(status: Int) async throws -> AnthropicClient {
        let elsewhere = try LoopbackHTTPServer { _ in .json(200, MockResponses.skillObject) }
        self.elsewhere = elsewhere
        let elsewhereURL = try await elsewhere.start()

        let origin = try LoopbackHTTPServer { _ in
            .redirect(status, to: elsewhereURL.appendingPathComponent("v1/skills/harvested"))
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
