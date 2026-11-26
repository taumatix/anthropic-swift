import Foundation

/// A single result from a completed batch, streamed as JSONL.
public struct BatchResult: Sendable, Decodable {
    public let customId: String
    public let result: BatchResultOutcome
}

/// The outcome of a single batch request item.
public enum BatchResultOutcome: Sendable, Decodable {
    case succeeded(message: MessageResponse)
    case errored(error: APIError)
    case canceled
    case expired
    /// A `result.type` this SDK does not know. Kept apart from `.canceled` so a new outcome kind
    /// is not reported as a cancellation.
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey { case type, message, error }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "succeeded":
            let message = try container.decode(MessageResponse.self, forKey: .message)
            self = .succeeded(message: message)
        case "errored":
            let error = try container.decode(APIError.self, forKey: .error)
            self = .errored(error: error)
        case "canceled":
            self = .canceled
        case "expired":
            self = .expired
        default:
            self = .unknown(type: type_)
        }
    }
}
