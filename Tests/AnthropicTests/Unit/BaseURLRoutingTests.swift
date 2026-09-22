import XCTest
@testable import Anthropic

/// `baseURL` must decide where requests actually go.
///
/// It did not. `ClientConfiguration.init` builds `URLSessionHTTPClient(baseURL:)` eagerly, so
/// setting `baseURL` afterwards — which is the only thing `ClientOptions.baseURL(_:)` does — left
/// the client pointed at `https://api.anthropic.com`. A caller routing through a gateway, a proxy,
/// a regional endpoint or a local test server sent their traffic and their API key to the public
/// API instead, with nothing in the response to say so.
final class BaseURLRoutingTests: XCTestCase {

    private static let gateway = URL(string: "https://gateway.internal.example")!

    func testOptionsBaseURLRetargetsTheDefaultHTTPClient() throws {
        let options = ClientOptions(apiKey: "test-key").baseURL(Self.gateway)
        let client = try XCTUnwrap(options.configuration.httpClient as? URLSessionHTTPClient)
        XCTAssertEqual(client.baseURL, Self.gateway)
    }

    func testMutatingConfigurationBaseURLRetargetsTheDefaultHTTPClient() throws {
        var configuration = ClientConfiguration(apiKey: "test-key")
        configuration.baseURL = Self.gateway
        let client = try XCTUnwrap(configuration.httpClient as? URLSessionHTTPClient)
        XCTAssertEqual(client.baseURL, Self.gateway)
    }

    func testInitialiserBaseURLIsHonoured() throws {
        let configuration = ClientConfiguration(apiKey: "test-key", baseURL: Self.gateway)
        let client = try XCTUnwrap(configuration.httpClient as? URLSessionHTTPClient)
        XCTAssertEqual(client.baseURL, Self.gateway)
    }

    /// A caller-supplied client owns its own routing: changing `baseURL` must not replace it.
    func testAnInjectedHTTPClientIsNeverReplaced() {
        var configuration = ClientConfiguration(apiKey: "test-key", httpClient: MockingClient())
        configuration.baseURL = Self.gateway
        XCTAssertTrue(configuration.httpClient is MockingClient,
                      "an injected client must survive a baseURL change")
    }

    /// Assigning a client after construction must also take ownership away from the SDK.
    func testAssigningAnHTTPClientTakesOwnership() {
        var configuration = ClientConfiguration(apiKey: "test-key")
        configuration.httpClient = MockingClient()
        configuration.baseURL = Self.gateway
        XCTAssertTrue(configuration.httpClient is MockingClient)
    }

    private struct MockingClient: HTTPClient {
        func send(_ request: HTTPRequest) async throws -> HTTPResponse {
            HTTPResponse(statusCode: 200)
        }
        func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }
}
