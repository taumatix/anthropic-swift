import XCTest
import Anthropic

/// Base class for integration tests that require a live Anthropic API key.
///
/// Tests that subclass this class are automatically skipped when
/// `ANTHROPIC_API_KEY` is not set in the environment.
///
/// Run integration tests with:
/// ```
/// ANTHROPIC_API_KEY=sk-ant-... swift test --filter Integration
/// ```
class IntegrationTestCase: XCTestCase {
    var client: AnthropicClient!

    override func setUpWithError() throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY environment variable is not set. Skipping integration test.")
        }
        client = AnthropicClient(
            apiKey: apiKey,
            options: ClientOptions(apiKey: apiKey).timeout(60).maxRetries(1)
        )
    }
}
