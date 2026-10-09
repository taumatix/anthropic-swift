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
    public let expiresAt: String?
    public let partialKeyHint: String?
    public let principal: APIKeyPrincipal?
    public let scope: APIKeyScope?
}

/// The user or service account an API key acts as.
public struct APIKeyPrincipal: Sendable, Decodable, Equatable {
    /// `user_actor` or `service_account_actor`.
    public let type: String
    public let userId: String?
    public let serviceAccountId: String?
}

/// Where an API key belongs: a workspace, or the organization itself.
public struct APIKeyScope: Sendable, Decodable, Equatable {
    /// `workspace` or `organization`.
    public let type: String
    public let workspaceId: String?
}

public struct APIKeyStatus: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let active = APIKeyStatus(rawValue: "active")
    public static let inactive = APIKeyStatus(rawValue: "inactive")
    public static let archived = APIKeyStatus(rawValue: "archived")
    public static let expired = APIKeyStatus(rawValue: "expired")
}

public struct APIKeyCreator: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
}
