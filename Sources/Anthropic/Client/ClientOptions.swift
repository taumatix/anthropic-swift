import Foundation

/// Fluent builder for `ClientConfiguration`.
///
/// Allows concise construction of a configured client:
/// ```swift
/// let client = AnthropicClient(
///     options: ClientOptions(apiKey: "sk-...")
///         .timeout(30)
///         .maxRetries(3)
/// )
/// ```
public struct ClientOptions: Sendable {
    var configuration: ClientConfiguration

    public init(apiKey: String) {
        self.configuration = ClientConfiguration(apiKey: apiKey)
    }

    public init(configuration: ClientConfiguration) {
        self.configuration = configuration
    }

    public func adminAPIKey(_ key: String) -> ClientOptions {
        var copy = self; copy.configuration.adminAPIKey = key; return copy
    }

    public func baseURL(_ url: URL) -> ClientOptions {
        var copy = self; copy.configuration.baseURL = url; return copy
    }

    public func anthropicVersion(_ version: String) -> ClientOptions {
        var copy = self; copy.configuration.anthropicVersion = version; return copy
    }

    public func timeout(_ interval: TimeInterval) -> ClientOptions {
        var copy = self; copy.configuration.timeout = interval; return copy
    }

    public func maxRetries(_ n: Int) -> ClientOptions {
        var copy = self; copy.configuration.maxRetries = n; return copy
    }

    public func retryPolicy(_ policy: RetryPolicy) -> ClientOptions {
        var copy = self; copy.configuration.retryPolicy = policy; return copy
    }

    public func additionalHeaders(_ headers: [String: String]) -> ClientOptions {
        var copy = self; copy.configuration.additionalHeaders = headers; return copy
    }

    public func httpClient(_ client: any HTTPClient) -> ClientOptions {
        var copy = self; copy.configuration.httpClient = client; return copy
    }
}
