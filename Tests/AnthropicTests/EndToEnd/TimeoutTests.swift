#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// `ClientConfiguration.timeout` is documented as the request timeout, default ten minutes for
/// streaming. Until 0.8.0 nothing read it: the SDK's transport ran on `URLSession.shared`, whose
/// own per-request timeout is 60 seconds, so a long streaming turn died at one minute having been
/// promised ten, and a short timeout a caller asked for never fired.
///
/// These run against a loopback server that answers late, through the SDK's own transport.
final class TimeoutTests: XCTestCase {

    private var server: LoopbackHTTPServer?

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    private func client(answeringAfter delay: TimeInterval, timeout: TimeInterval) async throws -> AnthropicClient {
        let server = try LoopbackHTTPServer { _ in
            Thread.sleep(forTimeInterval: delay)
            return .json(200, MockResponses.singleMessage)
        }
        self.server = server
        let baseURL = try await server.start()
        return AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key", baseURL: baseURL, timeout: timeout, maxRetries: 0
        ))
    }

    private func create(_ client: AnthropicClient) async throws -> MessageResponse {
        try await client.messages.create(
            MessageRequest(model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 16)
        )
    }

    /// The setting a caller made is the one that applies: a response slower than it times out.
    func testAResponseSlowerThanTheConfiguredTimeoutTimesOut() async throws {
        let client = try await client(answeringAfter: 1.5, timeout: 0.5)

        let started = Date()
        do {
            _ = try await create(client)
            XCTFail("a 0.5s timeout let a 1.5s response through; the setting is not applied")
        } catch AnthropicError.timeout {
            XCTAssertLessThan(Date().timeIntervalSince(started), 1.4, "it timed out, but not at the configured 0.5s")
        }
    }

    /// The companion: a response inside the timeout comes back, so the failure above is the
    /// timeout and not a server that never answers.
    func testAResponseInsideTheConfiguredTimeoutArrives() async throws {
        let client = try await client(answeringAfter: 0.3, timeout: 5)

        let response = try await create(client)

        XCTAssertFalse(response.id.isEmpty)
    }

    /// Streaming is the case the setting exists for, and it builds its request on a separate
    /// path, so it is checked on its own.
    func testAStreamSlowerThanTheConfiguredTimeoutTimesOut() async throws {
        let server = try LoopbackHTTPServer { _ in
            Thread.sleep(forTimeInterval: 1.5)
            return LoopbackHTTPServer.Response(status: 200, headers: ["Content-Type": "text/event-stream"],
                                               body: SSEFixtures.basicMessageStream)
        }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key", baseURL: baseURL, timeout: 0.5, maxRetries: 0
        ))

        do {
            for try await _ in client.messages.stream(
                MessageRequest(model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 16)
            ) {}
            XCTFail("a 0.5s timeout let a 1.5s stream through")
        } catch AnthropicError.timeout {
        }
    }

    /// The default is carried on every request the pipeline prepares, so a custom `HTTPClient`
    /// can honour it too.
    func testThePipelineCarriesTheTimeoutOnEveryRequest() async throws {
        let mock = MockHTTPClient()
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        let client = AnthropicClient(configuration: ClientConfiguration(apiKey: "k", timeout: 42, httpClient: mock))

        _ = try await create(client)

        XCTAssertEqual(mock.recordedRequests.first?.timeout, 42)
    }
}
#endif
