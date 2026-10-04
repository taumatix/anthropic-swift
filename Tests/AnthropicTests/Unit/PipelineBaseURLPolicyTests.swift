import XCTest
import Anthropic
import AnthropicTestSupport

/// "A plaintext `baseURL` is refused ... before a byte is sent" holds for every `HTTPClient`, not
/// only the SDK's own. The check used to live in `URLSessionHTTPClient`, so a client the caller
/// supplied (a pinned session wrapper, a proxy adapter) sent the key to `http://anywhere` while
/// the configuration said `allowsInsecureBaseURL = false`.
final class PipelineBaseURLPolicyTests: XCTestCase {

    private let gateway = URL(string: "http://gateway.internal.example")!
    private let request = MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)

    private func client(_ mock: MockHTTPClient, baseURL: URL, allowsInsecure: Bool = false) -> AnthropicClient {
        AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key", baseURL: baseURL, allowsInsecureBaseURL: allowsInsecure,
            maxRetries: 0, httpClient: mock
        ))
    }

    private func answering() -> MockHTTPClient {
        let mock = MockHTTPClient()
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream) }
        return mock
    }

    private func assertRefusal(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard case AnthropicError.networkError(let urlError) = error else {
            return XCTFail("expected the plaintext refusal, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(urlError.code, .appTransportSecurityRequiresSecureConnection, file: file, line: line)
    }

    func testACustomClientIsNotHandedARequestForAPlaintextBaseURL() async throws {
        let mock = answering()
        do {
            _ = try await client(mock, baseURL: gateway).messages.create(request)
            XCTFail("a request for a plaintext base URL went through a custom client")
        } catch { assertRefusal(error) }
        XCTAssertTrue(mock.recordedRequests.isEmpty, "the custom client was handed the request, key and all")
    }

    func testACustomClientIsNotHandedAStreamForAPlaintextBaseURL() async throws {
        let mock = answering()
        var events = 0
        do {
            for try await _ in client(mock, baseURL: gateway).messages.stream(request) { events += 1 }
            XCTFail("a stream for a plaintext base URL went through a custom client")
        } catch { assertRefusal(error) }
        XCTAssertEqual(events, 0)
        XCTAssertTrue(mock.recordedRequests.isEmpty, "the custom client was handed the stream request, key and all")
    }

    func testTheOptInStillWorksWithACustomClient() async throws {
        let mock = answering()
        _ = try await client(mock, baseURL: gateway, allowsInsecure: true).messages.create(request)
        XCTAssertEqual(mock.recordedRequests.count, 1)
    }

    func testLoopbackStillNeedsNoOptIn() async throws {
        let mock = answering()
        _ = try await client(mock, baseURL: URL(string: "http://127.0.0.1:8080")!).messages.create(request)
        XCTAssertEqual(mock.recordedRequests.count, 1)
    }

    /// The default base URL, and every https one, are untouched.
    func testHTTPSIsUntouched() async throws {
        let mock = answering()
        _ = try await client(mock, baseURL: URL(string: "https://api.anthropic.com")!).messages.create(request)
        XCTAssertEqual(mock.recordedRequests.count, 1)
    }
}
