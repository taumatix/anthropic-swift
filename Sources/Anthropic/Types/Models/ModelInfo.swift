import Foundation

/// Information about a Claude model returned by the Models API.
public struct ModelInfo: Sendable, Decodable, Equatable {
    /// Always `"model"`.
    public let type: String
    /// The model identifier (e.g., `"claude-opus-4-5"`).
    public let id: String
    /// The human-readable display name.
    public let displayName: String
    /// ISO 8601 timestamp when this model was created.
    public let createdAt: String
}
