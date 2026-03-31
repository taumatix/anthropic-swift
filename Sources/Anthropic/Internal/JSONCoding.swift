import Foundation

/// Shared JSON encoder and decoder configured for the Anthropic API.
///
/// All encoding and decoding in the SDK goes through these shared instances.
/// The Anthropic API uses snake_case keys — the auto-conversion strategy handles
/// this without requiring explicit `CodingKeys` enums on every type.
///
/// - Important: Never instantiate `JSONEncoder` or `JSONDecoder` elsewhere in the SDK.
///   Always use `JSONCoding.encoder` and `JSONCoding.decoder`.
enum JSONCoding {
    /// Shared encoder. Uses `.convertToSnakeCase` key strategy.
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    /// Shared decoder. Uses `.convertFromSnakeCase` key strategy.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
