import Foundation
import Anthropic

// MARK: - File Upload Example
//
// Demonstrates uploading a file and referencing it in a message.
//
// Usage:
//   ANTHROPIC_API_KEY=sk-ant-... swift run FileUpload

@main
struct FileUploadExample {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            fputs("Error: ANTHROPIC_API_KEY environment variable is not set.\n", stderr)
            exit(1)
        }

        let client = AnthropicClient(apiKey: apiKey)

        // Create a sample text file to upload
        let sampleContent = """
        # Q1 Sales Report

        Total revenue: $1,250,000
        Units sold: 4,200
        Top product: Widget Pro X
        Customer satisfaction: 92%

        Key insight: Widget Pro X exceeded expectations by 40% above forecast.
        """
        let fileData = Data(sampleContent.utf8)

        // Step 1: Upload the file
        print("Uploading file...")
        let fileObject = try await client.files.upload(
            content: fileData,
            filename: "q1_sales_report.txt",
            mimeType: "text/plain"
        )
        print("File uploaded: \(fileObject.id) (\(fileObject.filename), \(fileObject.size) bytes)")

        // Step 2: Reference the file in a message
        print("\nAsking Claude to summarize the report...")
        let response = try await client.messages.create(
            MessageRequest(
                model: .claude4Sonnet,
                messages: [
                    .user([
                        .document(.file(id: fileObject.id)),
                        .text("Please summarize the key findings from this sales report in 2-3 sentences."),
                    ])
                ],
                maxTokens: 512
            )
        )
        print("\nSummary:", response.textContent)

        // Step 3: Clean up — delete the file
        print("\nCleaning up...")
        let deleteResult = try await client.files.delete(id: fileObject.id)
        print("File deleted:", deleteResult.deleted)
    }
}
