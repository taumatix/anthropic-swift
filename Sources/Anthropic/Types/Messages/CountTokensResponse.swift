import Foundation

/// The response to a token count request.
public struct CountTokensResponse: Sendable, Decodable, Equatable {
    /// The number of input tokens that would be consumed by the request.
    public let inputTokens: Int
}
