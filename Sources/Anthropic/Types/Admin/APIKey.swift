import Foundation

/// An API key in the organization.
public struct OrganizationAPIKey: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
    public let name: String
    public let status: APIKeyStatus
    public let createdAt: String
    public let lastUsedAt: String?
    public let workspaceId: String?
    public let createdBy: APIKeyCreator?
}

public struct APIKeyStatus: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let active = APIKeyStatus(rawValue: "active")
    public static let inactive = APIKeyStatus(rawValue: "inactive")
}

public struct APIKeyCreator: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
}
