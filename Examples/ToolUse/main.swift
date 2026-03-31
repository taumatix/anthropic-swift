import Foundation
import Anthropic

// MARK: - Tool Use Example
//
// Demonstrates defining tools, handling tool_use content blocks,
// and completing the conversation with tool results.
//
// Usage:
//   ANTHROPIC_API_KEY=sk-ant-... swift run ToolUse

@main
struct ToolUseExample {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            fputs("Error: ANTHROPIC_API_KEY environment variable is not set.\n", stderr)
            exit(1)
        }

        let client = AnthropicClient(apiKey: apiKey)

        // Define a weather tool
        let weatherTool = Tool(
            name: "get_weather",
            description: "Get the current weather for a location.",
            inputSchema: .object(properties: [
                "location": .string(enumValues: nil, description: "City and state, e.g. 'San Francisco, CA'"),
                "unit": .string(enumValues: ["celsius", "fahrenheit"], description: "Temperature unit"),
            ], required: ["location"])
        )

        // Initial request with tool definition
        let initialRequest = MessageRequest(
            model: .claude4Sonnet,
            messages: [.user("What's the weather like in San Francisco?")],
            maxTokens: 1024,
            tools: [weatherTool]
        )

        print("Step 1: Sending initial request with tool...")
        let initialResponse = try await client.messages.create(initialRequest)

        guard let toolUse = initialResponse.firstToolUse else {
            print("Model did not request a tool. Response:", initialResponse.textContent)
            return
        }

        print("Model requested tool '\(toolUse.name)' with input: \(toolUse.input)")

        // Simulate a tool execution
        let weatherResult = """
        {"temperature": 65, "unit": "fahrenheit", "condition": "Partly cloudy", "humidity": 72}
        """

        // Continue the conversation with the tool result
        let followUpRequest = MessageRequest(
            model: .claude4Sonnet,
            messages: [
                .user("What's the weather like in San Francisco?"),
                .assistant(initialResponse.content.map { block -> ContentBlockParam in
                    switch block {
                    case .toolUse(let t): return .toolResult(toolUseId: t.id, content: nil, isError: nil)
                    case .text(let t): return .text(t.text)
                    default: return .text("")
                    }
                }),
                .user([.toolResult(
                    toolUseId: toolUse.id,
                    content: [.text(weatherResult)],
                    isError: nil
                )]),
            ],
            maxTokens: 1024,
            tools: [weatherTool]
        )
        print(jsonStringify(followUpRequest))

        // print("\nStep 2: Sending tool result...")
        // let finalResponse = try await client.messages.create(followUpRequest)
        // print("\nFinal response:", finalResponse.textContent)
    }
}
