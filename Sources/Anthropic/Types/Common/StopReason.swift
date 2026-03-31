import Foundation

/// The reason the model stopped generating content.
public struct StopReason: RawRepresentable, Sendable, Codable, Hashable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    /// The model reached a natural stopping point.
    public static let endTurn = StopReason(rawValue: "end_turn")
    /// A stop sequence was reached.
    public static let stopSequence = StopReason(rawValue: "stop_sequence")
    /// The maximum token limit was reached.
    public static let maxTokens = StopReason(rawValue: "max_tokens")
    /// The model invoked a tool.
    public static let toolUse = StopReason(rawValue: "tool_use")
}
