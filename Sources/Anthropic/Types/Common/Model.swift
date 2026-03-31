import Foundation

/// Identifies a Claude model.
///
/// Use the named constants for known models, or provide any string for custom/future models:
/// ```swift
/// let request = MessageRequest(model: .claude4Opus, ...)
/// let request = MessageRequest(model: "claude-3-5-sonnet-20241022", ...)
/// ```
public struct Model: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }

    // MARK: - Known Models

    // Claude 4 family
    public static let claude4Opus = Model(rawValue: "claude-opus-4-5")
    public static let claude4Sonnet = Model(rawValue: "claude-sonnet-4-5")
    public static let claude4Haiku = Model(rawValue: "claude-haiku-4-5-20251001")

    // Claude 3.7
    public static let claude37Sonnet = Model(rawValue: "claude-3-7-sonnet-20250219")

    // Claude 3.5 family
    public static let claude35Sonnet = Model(rawValue: "claude-3-5-sonnet-20241022")
    public static let claude35SonnetLatest = Model(rawValue: "claude-3-5-sonnet-latest")
    public static let claude35Haiku = Model(rawValue: "claude-3-5-haiku-20241022")
    public static let claude35HaikuLatest = Model(rawValue: "claude-3-5-haiku-latest")

    // Claude 3 family
    public static let claude3Opus = Model(rawValue: "claude-3-opus-20240229")
    public static let claude3Sonnet = Model(rawValue: "claude-3-sonnet-20240229")
    public static let claude3Haiku = Model(rawValue: "claude-3-haiku-20240307")
}
