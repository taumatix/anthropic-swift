import Foundation

/// Optional metadata attached to a message request.
public struct RequestMetadata: Sendable, Codable, Equatable {
    /// An external identifier for the user associated with this request.
    /// This helps Anthropic detect and address abuse.
    public let userId: String?

    public init(userId: String? = nil) {
        self.userId = userId
    }
}
