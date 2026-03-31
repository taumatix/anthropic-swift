import Foundation

/// A message batch object returned by the API.
public struct MessageBatch: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
    public let processingStatus: BatchProcessingStatus
    public let requestCounts: BatchRequestCounts
    public let endedAt: String?
    public let createdAt: String
    public let expiresAt: String
    public let cancelInitiatedAt: String?
    public let resultsUrl: String?
}

public struct BatchRequestCounts: Sendable, Decodable, Equatable {
    public let processing: Int
    public let succeeded: Int
    public let errored: Int
    public let canceled: Int
    public let expired: Int
}

public struct BatchProcessingStatus: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let inProgress = BatchProcessingStatus(rawValue: "in_progress")
    public static let canceling = BatchProcessingStatus(rawValue: "canceling")
    public static let ended = BatchProcessingStatus(rawValue: "ended")
}

/// Response to a batch delete request.
public struct BatchDeleteResponse: Sendable, Decodable {
    public let id: String
    public let type: String
}
