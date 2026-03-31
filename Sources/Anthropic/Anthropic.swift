import Foundation

/// The `Anthropic` namespace provides convenient type aliases and the SDK version.
///
/// You can use the full type names directly or via the namespace:
/// ```swift
/// let client = AnthropicClient(apiKey: "sk-...")
/// // or
/// let client = Anthropic.Client(apiKey: "sk-...")
/// ```
public enum Anthropic {
    /// The current SDK version.
    public static let version = "0.1.0"

    // MARK: - Type Aliases
    public typealias Client = AnthropicClient
    public typealias Error = AnthropicError
    public typealias Configuration = ClientConfiguration
    public typealias Options = ClientOptions
}
