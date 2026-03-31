import Foundation
import Anthropic

// MARK: - Basic Chat Example
//
// This example demonstrates the simplest usage of the Anthropic Swift SDK:
// creating a non-streaming message and printing the response.
//
// Usage:
//   ANTHROPIC_API_KEY=sk-ant-... swift run BasicChat

@main
struct BasicChat {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            fputs("Error: ANTHROPIC_API_KEY environment variable is not set.\n", stderr)
            exit(1)
        }

        let client = AnthropicClient(apiKey: apiKey)

        let response = try await client.messages.create(
            MessageRequest(
                model: .claude4Sonnet,
                messages: [.user("What is 2 + 2? Answer in one sentence.")],
                maxTokens: 256
            )
        )

        print(response.textContent)
        print("\n[Tokens used: \(response.usage.inputTokens) in, \(response.usage.outputTokens) out]")
    }
}
