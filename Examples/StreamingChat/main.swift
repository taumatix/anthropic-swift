import Foundation
import Anthropic

// MARK: - Streaming Chat Example
//
// Demonstrates streaming a response token-by-token using `.textStream`.
//
// Usage:
//   ANTHROPIC_API_KEY=sk-ant-... swift run StreamingChat

@main
struct StreamingChat {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            fputs("Error: ANTHROPIC_API_KEY environment variable is not set.\n", stderr)
            exit(1)
        }

        let client = AnthropicClient(apiKey: apiKey)

        let request = MessageRequest(
            model: .claude4Sonnet,
            messages: [.user("Write a haiku about programming in Swift.")],
            maxTokens: 256
        )

        print("Streaming response:\n")

        // Stream text incrementally — tokens appear as they are generated
        for try await text in client.messages.stream(request).textStream {
            print(text, terminator: "")
            fflush(stdout)
        }
        print("\n")

        // Alternatively: collect into a final MessageResponse (makes a second request)
        print("Collecting full response via second request...")
        let finalResponse = try await client.messages.stream(request).collect()
        print("[Output tokens: \(finalResponse.usage.outputTokens)]")
    }
}
