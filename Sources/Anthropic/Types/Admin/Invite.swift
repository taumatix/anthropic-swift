import Foundation

/// An invitation to join the organization.
public struct OrganizationInvite: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
    public let email: String
    public let role: OrganizationRole
    public let status: InviteStatus
    public let invitedAt: String
    public let expiresAt: String
}

public struct InviteStatus: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pending = InviteStatus(rawValue: "pending")
    public static let accepted = InviteStatus(rawValue: "accepted")
    public static let expired = InviteStatus(rawValue: "expired")
}

/// Request to create a new invitation.
public struct CreateInviteRequest: Sendable, Encodable {
    public let email: String
    public let role: OrganizationRole
    public init(email: String, role: OrganizationRole) {
        self.email = email
        self.role = role
    }
}

/// Response to an invite delete request.
public struct InviteDeleteResponse: Sendable, Decodable {
    public let id: String
    public let type: String
    public let deleted: Bool
}
