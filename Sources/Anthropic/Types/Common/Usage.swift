import Foundation

/// Token usage statistics for a request.
public struct Usage: Sendable, Codable, Equatable {
    /// The number of input tokens used.
    public let inputTokens: Int
    /// The number of output tokens generated.
    public let outputTokens: Int
    /// Cache creation input tokens (when using prompt caching).
    public let cacheCreationInputTokens: Int?
    /// Cache read input tokens (when using prompt caching).
    public let cacheReadInputTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }
}

/// Token usage delta reported in streaming message events.
public struct UsageDelta: Sendable, Codable, Equatable {
    public let outputTokens: Int
}
