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
private final class SeenURL: @unchecked Sendable {
    private let lock = NSLock()
    private var url: URL?
    func set(_ url: URL?) { lock.withLock { self.url = url } }
    func get() -> URL? { lock.withLock { url } }
}

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

    /// The same forgery, with the redirect guard out of the picture: a caller-injected
    /// `HTTPClient` that follows every redirect, as `URLSession` does by default. Only the
    /// pipeline's response-origin check stands between the foreign body and the caller.
    ///
    /// The unguarded client is asserted to have *reached* the foreign origin, so a pass cannot
    /// come from the redirect simply not being followed.
    func testAForgedResponseIsRefusedEvenWithoutTheRedirectGuard() async throws {
        let elsewhere = try LoopbackHTTPServer { _ in .json(200, Self.forgedMessage) }
        self.elsewhere = elsewhere
        let elsewhereURL = try await elsewhere.start()

        let origin = try LoopbackHTTPServer { _ in
            .redirect(302, to: elsewhereURL.appendingPathComponent("v1/messages"))
        }
        self.origin = origin
        let originURL = try await origin.start()

        let client = AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key",
            baseURL: originURL,
            maxRetries: 0,
            httpClient: UnguardedHTTPClient(baseURL: originURL)
        ))

        do {
            let response = try await client.messages.create(
                MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
            )
            XCTFail("a forged response was returned to the caller as the API's answer: \(response.id)")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
            XCTAssertEqual(error.failingURL?.port, elsewhereURL.port)
        }

        XCTAssertEqual(elsewhere.receivedRequests.count, 1,
                       "the unguarded client never followed the redirect, so this proves nothing")
    }

    /// The streaming half of the test above. A stream hands the pipeline no response, so until
    /// `stream(_:validatingResponseFrom:)` a caller's transport that followed a redirect delivered
    /// the foreign origin's SSE as `MessageStreamEvent`s.
    func testAForgedStreamIsRefusedEvenWithoutTheRedirectGuard() async throws {
        let (client, elsewhere) = try await startUnguardedClientRedirectingToAForgedStream {
            UnguardedHTTPClient(baseURL: $0)
        }

        var events = 0
        do {
            for try await _ in client.messages.stream(
                MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
            ) { events += 1 }
            XCTFail("a forged stream was delivered to the caller as the API's")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
            XCTAssertEqual(error.failingURL?.port, elsewhere.port)
        }
        XCTAssertEqual(events, 0, "forged events reached the caller")
        XCTAssertEqual(self.elsewhere?.receivedRequests.count, 1,
                       "the unguarded client never followed the redirect, so this proves nothing")
    }

    /// `URLSessionHTTPClient` also checks a stream against its own `baseURL`, which always agrees
    /// with the pipeline's, so every test above passes whether or not it calls the `validate` it
    /// was handed. This drives it directly, over a real socket, with a `validate` that refuses.
    func testTheSDKTransportCallsTheValidateItIsGiven() async throws {
        let server = try LoopbackHTTPServer { _ in .json(200, Data("data: {}\n\n".utf8)) }
        self.origin = server
        let baseURL = try await server.start()

        struct Refused: Error {}
        let seen = SeenURL()
        let transport = URLSessionHTTPClient(baseURL: baseURL, allowsInsecureBaseURL: true)
        var chunks = 0
        do {
            for try await _ in transport.stream(
                HTTPRequest(method: "POST", path: "/v1/messages"),
                validatingResponseFrom: { url in seen.set(url); throw Refused() }
            ) { chunks += 1 }
            XCTFail("the stream went ahead although validate threw")
        } catch is Refused {}

        XCTAssertEqual(chunks, 0, "bytes were yielded before validate was consulted")
        XCTAssertEqual(seen.get()?.port, baseURL.port, "validate was not given the response's URL")
    }

    /// The companion: a transport written before the new method existed still streams. Unchecked,
    /// which is the documented cost of not adopting it, but not broken.
    func testATransportWithoutTheNewMethodStillStreams() async throws {
        let (client, _) = try await startUnguardedClientRedirectingToAForgedStream {
            PreexistingHTTPClient(inner: UnguardedHTTPClient(baseURL: $0))
        }

        var events = 0
        for try await _ in client.messages.stream(
            MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)
        ) { events += 1 }

        XCTAssertGreaterThan(events, 0, "a pre-existing transport stopped streaming")
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

    /// A caller's own transport: plain `URLSession`, which follows redirects, reporting the URL
    /// the response actually came from. This is the shape the redirect guard cannot reach.
    private struct UnguardedHTTPClient: HTTPClient {
        let baseURL: URL

        func send(_ request: HTTPRequest) async throws -> HTTPResponse {
            let (data, response) = try await URLSession.shared.data(for: urlRequest(request))
            let http = try XCTUnwrap(response as? HTTPURLResponse)
            return HTTPResponse(statusCode: http.statusCode, body: data, url: http.url)
        }

        func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
            stream(request, validatingResponseFrom: { _ in })
        }

        /// What a caller's transport does to opt into the origin check: report where the
        /// response came from before handing over a byte of it.
        func stream(
            _ request: HTTPRequest,
            validatingResponseFrom validate: @escaping @Sendable (URL?) throws -> Void
        ) -> AsyncThrowingStream<Data, Error> {
            let urlRequest = urlRequest(request)
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                        try validate(response.url)
                        var line = Data()
                        for try await byte in bytes {
                            line.append(byte)
                            if byte == UInt8(ascii: "\n") { continuation.yield(line); line = Data() }
                        }
                        if !line.isEmpty { continuation.yield(line) }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }

        private func urlRequest(_ request: HTTPRequest) -> URLRequest {
            var urlRequest = URLRequest(url: baseURL.appendingPathComponent(request.path))
            urlRequest.httpMethod = request.method
            urlRequest.httpBody = request.body
            request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
            return urlRequest
        }
    }

    /// A caller's transport written before `stream(_:validatingResponseFrom:)` existed. It must
    /// keep compiling and keep streaming, unchecked, rather than start failing.
    private struct PreexistingHTTPClient: HTTPClient {
        let inner: UnguardedHTTPClient

        func send(_ request: HTTPRequest) async throws -> HTTPResponse { try await inner.send(request) }
        func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> { inner.stream(request) }
    }

    /// An origin that redirects to another serving a well-formed SSE stream, behind a client built
    /// by `transport`. Returns the client and the foreign origin's URL.
    private func startUnguardedClientRedirectingToAForgedStream(
        _ transport: (URL) -> any HTTPClient
    ) async throws -> (AnthropicClient, URL) {
        let elsewhere = try LoopbackHTTPServer { _ in
            LoopbackHTTPServer.Response(status: 200, headers: ["Content-Type": "text/event-stream"],
                                        body: SSEFixtures.basicMessageStream)
        }
        self.elsewhere = elsewhere
        let elsewhereURL = try await elsewhere.start()

        let origin = try LoopbackHTTPServer { _ in
            .redirect(307, to: elsewhereURL.appendingPathComponent("v1/messages"))
        }
        self.origin = origin
        let originURL = try await origin.start()

        let client = AnthropicClient(configuration: ClientConfiguration(
            apiKey: "test-key", baseURL: originURL, maxRetries: 0, httpClient: transport(originURL)
        ))
        return (client, elsewhereURL)
    }

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
