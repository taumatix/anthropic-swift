#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// `cache_control`, `service_tier`, `inference_geo` and `output_config` as they arrive on a real socket,
/// in the shapes the Messages reference gives (retrieved 2026-10-09). Not covered: which models accept
/// which value, and the live API.
final class RequestOptionsEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    private func body(_ request: MessageRequest) async throws -> [String: Any] {
        let server = try LoopbackHTTPServer { _ in .json(200, MockResponses.singleMessage) }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))
        _ = try await client.messages.create(request)
        let last = try XCTUnwrap(server.receivedRequests.last)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: last.body) as? [String: Any])
    }

    func testEveryNewOptionReachesTheWireAsDocumented() async throws {
        let json = try await body(MessageRequest(
            model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 64,
            cacheControl: CacheControl(ttl: .oneHour),
            serviceTier: .standardOnly,
            inferenceGeo: "us-west-2",
            outputConfig: OutputConfig(
                effort: .xhigh,
                jsonSchema: .object(properties: ["answer": .string()], required: ["answer"]))))

        XCTAssertEqual(json["cache_control"] as? NSDictionary, ["type": "ephemeral", "ttl": "1h"])
        XCTAssertEqual(json["service_tier"] as? String, "standard_only")
        XCTAssertEqual(json["inference_geo"] as? String, "us-west-2")
        let output = try XCTUnwrap(json["output_config"] as? [String: Any])
        XCTAssertEqual(output["effort"] as? String, "xhigh")
        let format = try XCTUnwrap(output["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])
        XCTAssertEqual(schema["type"] as? String, "object")
        XCTAssertEqual(schema["required"] as? [String], ["answer"])
    }

    func testDefaultsAreNotSentAndTheDefaultTTLIsLeftToTheAPI() async throws {
        var json = try await body(MessageRequest(
            model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 64))
        for key in ["cache_control", "service_tier", "inference_geo", "output_config"] {
            XCTAssertNil(json[key], "\(key) is not sent when unset")
        }
        json = try await body(MessageRequest(
            model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 64,
            cacheControl: CacheControl(), serviceTier: .auto, outputConfig: OutputConfig(effort: .low)))
        XCTAssertEqual(json["cache_control"] as? NSDictionary, ["type": "ephemeral"])
        XCTAssertEqual(json["service_tier"] as? String, "auto")
        XCTAssertEqual((json["output_config"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertNil((json["output_config"] as? [String: Any])?["format"])
    }

    func testACacheBreakpointOnAToolReachesTheWireAndOnlyOnThatTool() async throws {
        let schema = JSONSchema.object(properties: ["city": .string()], required: ["city"])
        let json = try await body(MessageRequest(
            model: .claudeSonnet55, messages: [.user("hi")], maxTokens: 64,
            tools: [
                Tool(name: "first", description: "no breakpoint", inputSchema: schema),
                Tool(name: "last", inputSchema: schema, cacheControl: CacheControl(ttl: .oneHour)),
            ]))
        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 2)
        XCTAssertNil(tools[0]["cache_control"], "a tool without a breakpoint sends none")
        XCTAssertEqual(tools[1]["cache_control"] as? NSDictionary, ["type": "ephemeral", "ttl": "1h"])
        XCTAssertNil(tools[1]["cacheControl"], "the key is snake_case on the wire")
    }

    func testAToolRoundTripsWithAndWithoutABreakpoint() throws {
        let plain = Tool(name: "t", inputSchema: .object(properties: [:]))
        let cached = Tool(name: "t", inputSchema: .object(properties: [:]), cacheControl: CacheControl())
        for tool in [plain, cached] {
            let data = try JSONEncoder().encode(tool)
            XCTAssertEqual(try JSONDecoder().decode(Tool.self, from: data), tool)
        }
        XCTAssertNil(plain.cacheControl)
    }
}
#endif
