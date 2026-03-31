import Foundation
import Anthropic

// MARK: - Batch Processing Example
//
// Demonstrates creating a message batch, polling for completion,
// and streaming the results.
//
// Usage:
//   ANTHROPIC_API_KEY=sk-ant-... swift run BatchProcessing

@main
struct BatchProcessingExample {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            fputs("Error: ANTHROPIC_API_KEY environment variable is not set.\n", stderr)
            exit(1)
        }

        let client = AnthropicClient(apiKey: apiKey)

        // Create a batch of 3 questions
        let questions = [
            ("q1", "What is the capital of France?"),
            ("q2", "What is 15 × 17?"),
            ("q3", "Name three programming languages created after 2000."),
        ]

        let batchItems = questions.map { id, question in
            BatchRequestItem(
                customId: id,
                params: MessageRequest(
                    model: .claude4Haiku,
                    messages: [.user(question)],
                    maxTokens: 256
                )
            )
        }

        // Step 1: Create the batch
        print("Creating batch with \(batchItems.count) requests...")
        let batch = try await client.batches.create(BatchCreateRequest(requests: batchItems))
        print("Batch created: \(batch.id)")
        print("Status: \(batch.processingStatus.rawValue)")

        // Step 2: Poll until complete (in production, use webhooks instead)
        var currentBatch = batch
        print("\nPolling for completion...")
        while currentBatch.processingStatus != .ended {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            currentBatch = try await client.batches.get(id: batch.id)
            let counts = currentBatch.requestCounts
            print("  Status: \(currentBatch.processingStatus.rawValue) — " +
                  "processing: \(counts.processing), succeeded: \(counts.succeeded)")
        }

        print("\nBatch complete!")
        print("Succeeded: \(currentBatch.requestCounts.succeeded)")
        print("Errored: \(currentBatch.requestCounts.errored)")

        // Step 3: Stream results
        if currentBatch.processingStatus == .ended {
            print("\nResults:")
            print(String(repeating: "-", count: 40))
            for try await result in client.batches.results(id: batch.id) {
                print("[\(result.customId)]")
                switch result.result {
                case .succeeded(let message):
                    print(message.textContent)
                case .errored(let error):
                    print("Error:", error.error.message)
                case .canceled:
                    print("(canceled)")
                case .expired:
                    print("(expired)")
                }
                print()
            }
        }
    }
}
