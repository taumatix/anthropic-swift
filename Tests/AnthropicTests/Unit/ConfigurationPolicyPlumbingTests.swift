import XCTest
@testable import Anthropic

/// The configuration's stated policy must be the transport's actual policy, by every route into
/// it.
///
/// Each of these covers a path that once let the two disagree — a configuration reporting
/// `allowsInsecureBaseURL = false` over a transport built with `true`, or a `baseURL` the caller
/// set over a transport still pointed at the default host.
final class ConfigurationPolicyPlumbingTests: XCTestCase {

    private static let gateway = URL(string: "http://gateway.internal.example")!

    private func transport(of configuration: ClientConfiguration) throws -> URLSessionHTTPClient {
        try XCTUnwrap(configuration.httpClient as? URLSessionHTTPClient)
    }

    /// The setter was the one way in that skipped `retargetStoredHTTPClient()`, so
    /// `.baseURL(gateway).allowsInsecureBaseURL(true).httpClient(pinned)` — the documented way to
    /// supply a pinned `URLSession` — produced a transport on the default host with the opt-out
    /// unset.
    func testAssigningAnHTTPClientAdoptsTheConfigurationsPolicy() throws {
        var configuration = ClientConfiguration(apiKey: "test-key")
        configuration.baseURL = Self.gateway
        configuration.allowsInsecureBaseURL = true

        configuration.httpClient = URLSessionHTTPClient()

        let transport = try transport(of: configuration)
        XCTAssertEqual(transport.baseURL, Self.gateway)
        XCTAssertTrue(transport.allowsInsecureBaseURL)
    }

    /// And the other direction: a transport built permissively must not outlive a configuration
    /// that says otherwise.
    func testAPermissiveClientCannotSurviveAStricterConfiguration() throws {
        var configuration = ClientConfiguration(apiKey: "test-key")

        configuration.httpClient = URLSessionHTTPClient(
            baseURL: Self.gateway,
            allowsInsecureBaseURL: true
        )

        XCTAssertFalse(try transport(of: configuration).allowsInsecureBaseURL,
                       "the configuration says false, so the transport must not permit plaintext")
    }

    /// Same smuggling route through `init(httpClient:)` rather than the setter.
    func testAnInjectedClientAtInitAdoptsTheConfigurationsPolicy() throws {
        let configuration = ClientConfiguration(
            apiKey: "test-key",
            baseURL: ClientConfiguration.defaultBaseURL,
            allowsInsecureBaseURL: false,
            httpClient: URLSessionHTTPClient(baseURL: Self.gateway, allowsInsecureBaseURL: true)
        )

        let transport = try transport(of: configuration)
        XCTAssertFalse(transport.allowsInsecureBaseURL)
        XCTAssertEqual(transport.baseURL, ClientConfiguration.defaultBaseURL)
    }

    /// End to end through the refusal, not just the stored flag: a smuggled permissive client must
    /// not be able to actually send to a plaintext host.
    func testASmuggledPermissiveClientStillRefusesPlaintext() async throws {
        var configuration = ClientConfiguration(apiKey: "test-key")
        configuration.baseURL = Self.gateway
        configuration.httpClient = URLSessionHTTPClient(
            baseURL: Self.gateway,
            allowsInsecureBaseURL: true
        )

        do {
            _ = try await configuration.httpClient.send(HTTPRequest(method: "GET", path: "/v1/skills"))
            XCTFail("plaintext should have been refused")
        } catch AnthropicError.networkError(let urlError) {
            XCTAssertEqual(urlError.code, .appTransportSecurityRequiresSecureConnection)
        }
    }

    /// `reconfigured(baseURL:allowsInsecureBaseURL:)` exists so a caller's pinned or proxied
    /// session survives a policy change. Falling back to `.shared` would silently defeat pinning.
    func testReconfiguringPreservesTheCallersURLSession() throws {
        let pinned = URLSession(configuration: .ephemeral)
        var configuration = ClientConfiguration(apiKey: "test-key")
        configuration.httpClient = URLSessionHTTPClient(session: pinned)

        configuration.baseURL = Self.gateway
        configuration.allowsInsecureBaseURL = true

        XCTAssertTrue(try transport(of: configuration).session === pinned,
                      "the caller's session was replaced, which would defeat TLS pinning")
    }

    /// A client that is not the SDK's own does its own routing and must never be rebuilt.
    func testANonURLSessionClientIsNeverReplaced() {
        var configuration = ClientConfiguration(apiKey: "test-key", httpClient: MockingClient())
        configuration.baseURL = Self.gateway
        configuration.allowsInsecureBaseURL = true
        XCTAssertTrue(configuration.httpClient is MockingClient)
    }

    private struct MockingClient: HTTPClient {
        func send(_ request: HTTPRequest) async throws -> HTTPResponse { HTTPResponse(statusCode: 200) }
        func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }
}
