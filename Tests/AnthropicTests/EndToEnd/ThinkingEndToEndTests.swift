#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// The `thinking` request parameter as it arrives on a real socket, in the four shapes the Messages
/// reference gives (retrieved 2026-10-09). Not covered: which models accept which shape, and the
/// live API.
final class ThinkingEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    func testEveryThinkingShapeReachesTheWireAsDocumented() async throws {
        let server = try LoopbackHTTPServer { _ in .json(200, MockResponses.singleMessage) }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))

        let shapes: [(ThinkingConfig?, [String: Any]?)] = [
            (.enabled(budgetTokens: 2048), ["type": "enabled", "budget_tokens": 2048]),
            (.enabled(budgetTokens: 1024, display: .omitted),
             ["type": "enabled", "budget_tokens": 1024, "display": "omitted"]),
            (.disabled, ["type": "disabled"]),
            (.adaptive(), ["type": "adaptive"]),
            (.adaptive(display: .summarized), ["type": "adaptive", "display": "summarized"]),
            (.betweenTools, ["type": "between_tools"]),
            (nil, nil),
        ]
        for (config, _) in shapes {
            _ = try await client.messages.create(MessageRequest(
                model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 4096, thinking: config))
        }

        let requests = server.receivedRequests
        XCTAssertEqual(requests.count, shapes.count)
        for (request, shape) in zip(requests, shapes) {
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: request.body) as? [String: Any])
            if let want = shape.1 {
                XCTAssertEqual(json["thinking"] as? NSDictionary, want as NSDictionary)
            } else {
                XCTAssertNil(json["thinking"], "an unset thinking is not sent")
            }
        }
    }
}
#endif
