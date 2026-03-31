import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class MessagesServiceTests: XCTestCase {

    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    // MARK: - create

    func testCreateMessageSendsCorrectMethod() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        _ = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hello")], maxTokens: 100)
        )
        XCTAssertEqual(mock.recordedRequests.first?.method, "POST")
    }

    func testCreateMessageSendsCorrectPath() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        _ = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hello")], maxTokens: 100)
        )
        XCTAssertEqual(mock.recordedRequests.first?.path, "/v1/messages")
    }

    func testCreateMessageInjectsAPIKeyHeader() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.headers["x-api-key"], "test-key")
            return HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
        }
        _ = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
        )
    }

    func testCreateMessageInjectsVersionHeader() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")
            return HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
        }
        _ = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
        )
    }

    func testCreateMessageDecodesResponse() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        let response = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
        )
        XCTAssertEqual(response.id, "msg_01XFDUDYJgAACzvnptvVoYEL")
        XCTAssertEqual(response.textContent, "Hello! How can I help you today?")
        XCTAssertEqual(response.usage.inputTokens, 10)
        XCTAssertEqual(response.usage.outputTokens, 9)
    }

    func testCreateMessageDoesNotSetStreamTrue() async throws {
        mock.handler = { request in
            // Verify stream is not true in the body
            if let body = request.body,
               let dict = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertNotEqual(dict["stream"] as? Bool, true)
            }
            return HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
        }
        _ = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
        )
    }

    // MARK: - Error handling

    func testCreateMessage401ThrowsAuthError() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 401, body: MockResponses.authError) }
        do {
            _ = try await client.messages.create(
                MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
            )
            XCTFail("Should have thrown")
        } catch AnthropicError.authenticationFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateMessage429ThrowsRateLimited() async throws {
        mock.handler = { _ in
            HTTPResponse(statusCode: 429, headers: ["retry-after": "5"], body: MockResponses.rateLimitError)
        }
        // Override retry policy to not retry in tests
        let config = ClientConfiguration(
            apiKey: "test-key",
            maxRetries: 0,
            httpClient: mock
        )
        let noRetryClient = AnthropicClient(configuration: config)
        do {
            _ = try await noRetryClient.messages.create(
                MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
            )
            XCTFail("Should have thrown")
        } catch AnthropicError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 5.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - countTokens

    func testCountTokensSendsCorrectPath() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.tokenCount) }
        let response = try await client.messages.countTokens(
            CountTokensRequest(model: .claude4Sonnet, messages: [.user("Hello")])
        )
        XCTAssertEqual(mock.recordedRequests.first?.path, "/v1/messages/count_tokens")
        XCTAssertEqual(response.inputTokens, 42)
    }
}
