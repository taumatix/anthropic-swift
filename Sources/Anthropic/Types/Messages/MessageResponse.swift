import Foundation

/// A message response from the Anthropic API.
public struct MessageResponse: Sendable, Decodable, Equatable {
    /// The unique message identifier.
    public let id: String
    /// Always `"message"`.
    public let type: String
    /// Always `"assistant"`.
    public let role: String
    /// The generated content blocks.
    public let content: [ContentBlock]
    /// The model that generated this response.
    public let model: Model
    /// The reason the model stopped generating.
    public let stopReason: StopReason?
    /// The stop sequence that was matched, if any.
    public let stopSequence: String?
    /// Token usage statistics.
    public let usage: Usage

    // MARK: - Convenience

    /// Returns all text from `text` content blocks, joined together.
    public var textContent: String {
        content.compactMap { $0.text }.joined()
    }

    /// Returns the first tool use block, if any.
    public var firstToolUse: ContentBlock.ToolUseBlock? {
        for block in content {
            if case .toolUse(let tool) = block { return tool }
        }
        return nil
    }
}
