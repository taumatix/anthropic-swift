#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// `BaseURLPolicy` decides; these prove it is actually consulted, on both transports, by a real
/// `AnthropicClient` rather than by a direct call to the policy.
///
/// A policy nothing calls is the defect this repo keeps finding — `baseURL` itself was stored and
/// unread until 2026-09-22, and `timeout` still is.
final class InsecureBaseURLTests: XCTestCase {

    private var server: LoopbackHTTPServer?

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    /// `.invalid` is reserved by RFC 2606 and cannot resolve, so a test that gets past the refusal
    /// fails on a name lookup instead of reaching anybody.
    private static let plaintextGateway = URL(string: "http://gateway.invalid")!

    private func client(baseURL: URL, allowsInsecure: Bool = false) -> AnthropicClient {
        AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key")
                .baseURL(baseURL)
                .allowsInsecureBaseURL(allowsInsecure)
                .maxRetries(0)
        )
    }

    private func assertRefused(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard case AnthropicError.networkError(let urlError) = error else {
            return XCTFail("expected .networkError, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(urlError.code, .appTransportSecurityRequiresSecureConnection,
                       file: file, line: line)
    }

    // MARK: - Refused

    func testAPlaintextBaseURLIsRefusedOnTheUnaryPath() async throws {
        do {
            _ = try await client(baseURL: Self.plaintextGateway).skills.list()
            XCTFail("a plaintext baseURL should not be usable")
        } catch {
            assertRefused(error)
        }
    }

    /// Streaming builds its request on a separate path, so it needs its own check — the same split
    /// that let the redirect leak sit in `bytes(for:)` after `data(for:)` was guarded.
    func testAPlaintextBaseURLIsRefusedOnTheStreamingPath() async throws {
        let stream = client(baseURL: Self.plaintextGateway).messages.stream(
            MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
        )
        do {
            for try await _ in stream {}
            XCTFail("a plaintext baseURL should not be usable for streaming either")
        } catch {
            assertRefused(error)
        }
    }

    // MARK: - Allowed

    /// The loopback exemption has to survive contact with a real socket, and by hostname rather
    /// than only by literal — `localhost` is what a person types.
    func testLoopbackOverPlaintextStillReachesARealServer() async throws {
        let server = try LoopbackHTTPServer { _ in .json(200, MockResponses.skillObject) }
        self.server = server
        let bound = try await server.start()
        let baseURL = try XCTUnwrap(URL(string: "http://localhost:\(try XCTUnwrap(bound.port))"))

        let skill = try await client(baseURL: baseURL).skills.get(id: "skill_01JAbcdefghijklmnopqrstuvw")

        XCTAssertEqual(skill.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(server.receivedRequests.count, 1, "the request never reached the server")
    }

    /// The opt-out has to reach the transport, not just exist on the configuration. It resolves a
    /// name that cannot resolve, so getting a *different* network error is the proof that the
    /// refusal was waived and the request was attempted.
    func testTheOptOutReachesTheTransport() async throws {
        do {
            _ = try await client(baseURL: Self.plaintextGateway, allowsInsecure: true).skills.list()
            XCTFail("gateway.invalid cannot resolve, so this should not have succeeded")
        } catch AnthropicError.networkError(let urlError) {
            XCTAssertNotEqual(urlError.code, .appTransportSecurityRequiresSecureConnection,
                              "the opt-out did not reach the transport")
        }
    }
}
#endif
