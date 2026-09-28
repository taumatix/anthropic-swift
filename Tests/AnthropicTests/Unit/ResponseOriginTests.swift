import XCTest
@testable import Anthropic
import AnthropicTestSupport

/// `RequestPipeline` refuses a response whose origin is not the configured `baseURL`'s.
///
/// The redirect guard stops `URLSessionHTTPClient` from following a hop off the caller's origin,
/// but it is one mechanism in one implementation of a public protocol. These tests hold the
/// second check, which sits where every unary response passes through.
final class ResponseOriginTests: XCTestCase {

    private let base = URL(string: "https://api.anthropic.com")!

    private func client(returning response: HTTPResponse, baseURL: URL? = nil) -> AnthropicClient {
        let mock = MockHTTPClient()
        mock.handler = { _ in response }
        return AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key",
            baseURL: baseURL ?? base,
            httpClient: mock
        ))
    }

    private func create(_ client: AnthropicClient) async throws -> MessageResponse {
        try await client.messages.create(
            MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
        )
    }

    func testAResponseFromAnotherOriginIsRefused() async throws {
        let forged = HTTPResponse(
            statusCode: 200,
            body: MockResponses.singleMessage,
            url: URL(string: "https://attacker.example/v1/messages")!
        )

        do {
            let response = try await create(client(returning: forged))
            XCTFail("a response from another origin was decoded and returned: \(response.id)")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
            XCTAssertEqual(error.failingURL?.host, "attacker.example",
                           "the error should name where the response came from")
        }
    }

    /// Scheme and port are part of the origin: a plaintext reply on the same host, or one from
    /// another port, is not the API the caller configured.
    func testSchemeAndPortArePartOfTheOrigin() async throws {
        for foreign in ["http://api.anthropic.com/v1/messages", "https://api.anthropic.com:8443/v1/messages"] {
            let response = HTTPResponse(statusCode: 200, body: MockResponses.singleMessage,
                                        url: URL(string: foreign)!)
            do {
                _ = try await create(client(returning: response))
                XCTFail("\(foreign) was accepted as the configured origin")
            } catch AnthropicError.networkError(let error) {
                XCTAssertEqual(error.code, .badServerResponse, foreign)
            }
        }
    }

    /// An error body from another origin must not be decoded either — a forged `APIError` can say
    /// anything, including that the key is invalid.
    func testAnErrorResponseFromAnotherOriginIsRefusedToo() async throws {
        let forged = HTTPResponse(statusCode: 401, body: Data("{}".utf8),
                                  url: URL(string: "https://attacker.example/v1/messages")!)

        do {
            _ = try await create(client(returning: forged))
            XCTFail("expected a refusal")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }

    func testASameOriginResponseIsAccepted() async throws {
        let moved = HTTPResponse(statusCode: 200, body: MockResponses.singleMessage,
                                 url: URL(string: "https://API.anthropic.com:443/v1/moved")!)

        let response = try await create(client(returning: moved))

        XCTAssertFalse(response.id.isEmpty)
    }

    /// A `baseURL` with a path prefix — a gateway — is one origin with everything under it.
    func testAGatewayBaseURLWithAPathMatchesOnOriginOnly() async throws {
        let gateway = URL(string: "https://gateway.example/anthropic")!
        let reply = HTTPResponse(statusCode: 200, body: MockResponses.singleMessage,
                                 url: URL(string: "https://gateway.example/anthropic/v1/messages")!)

        let response = try await create(client(returning: reply, baseURL: gateway))

        XCTAssertFalse(response.id.isEmpty)
    }

    /// `HTTPResponse.url` is new. A caller's `HTTPClient` written before it existed leaves it
    /// `nil`, and must keep working rather than start refusing every response.
    func testAResponseWithNoURLIsAccepted() async throws {
        let unattributed = HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)

        let response = try await create(client(returning: unattributed))

        XCTAssertFalse(response.id.isEmpty)
    }

    /// A `URLProtocol` the app registers is below the redirect guard: it answers the request
    /// itself, from whatever URL it likes. Both of the SDK's own paths must still refuse.
    func testURLSessionHTTPClientRefusesAForeignResponseFromAURLProtocol() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ForgingURLProtocol.self]
        let transport = URLSessionHTTPClient(session: URLSession(configuration: configuration), baseURL: base)
        let client = AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key", baseURL: base, maxRetries: 0, httpClient: transport
        ))

        do {
            _ = try await create(client)
            XCTFail("a unary response from a URLProtocol's foreign origin was accepted")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }

        var events = 0
        do {
            for try await _ in client.messages.stream(
                MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
            ) { events += 1 }
            XCTFail("a streamed response from a URLProtocol's foreign origin was accepted")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }
        XCTAssertEqual(events, 0, "forged stream events reached the caller")
        XCTAssertGreaterThanOrEqual(ForgingURLProtocol.served, 2,
                                    "the protocol never answered, so this proves nothing")
    }

    /// The SDK's own transport must attribute its responses, or the check above is inert for the
    /// only client most callers use.
    func testURLSessionHTTPClientReportsTheResponseURL() async throws {
        #if canImport(Network)
        let server = try LoopbackHTTPServer { _ in .json(200, MockResponses.singleMessage) }
        defer { server.stop() }
        let baseURL = try await server.start()
        let transport = URLSessionHTTPClient(baseURL: baseURL)

        let response = try await transport.send(HTTPRequest(method: "POST", path: "/v1/messages"))

        let url = try XCTUnwrap(response.url, "URLSessionHTTPClient left HTTPResponse.url empty")
        XCTAssertEqual(url.port, baseURL.port)
        XCTAssertEqual(url.path, "/v1/messages")
        #endif
    }
}

/// Answers every request with a success from `attacker.example`, as an app-registered protocol
/// (a caching layer, a debugging proxy) could. The body is valid for both a unary message and an
/// SSE stream, so a pass cannot come from the body failing to parse.
private final class ForgingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var served = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.served += 1
        let forgedURL = URL(string: "https://attacker.example/v1/messages")!
        let isStream = String(decoding: request.httpBody ?? request.bodyStreamData(), as: UTF8.self)
            .contains("\"stream\":true")
        let body = isStream
            ? Data("event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n".utf8)
            : MockResponses.singleMessage
        let response = HTTPURLResponse(url: forgedURL, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["content-type": isStream ? "text/event-stream" : "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    /// URLSession moves a body into a stream before a protocol sees it.
    func bodyStreamData() -> Data {
        guard let stream = httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
