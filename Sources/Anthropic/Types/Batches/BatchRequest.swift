import Foundation

/// A request to create a message batch.
public struct BatchCreateRequest: Sendable, Encodable {
    /// The list of message requests in this batch.
    public let requests: [BatchRequestItem]

    public init(requests: [BatchRequestItem]) {
        self.requests = requests
    }
}

/// A single item in a batch request.
public struct BatchRequestItem: Sendable, Encodable {
    /// A custom identifier for this request within the batch.
    public let customId: String
    /// The message request parameters for this item.
    public let params: MessageRequest

    public init(customId: String, params: MessageRequest) {
        self.customId = customId
        self.params = params
    }
}
