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
    public let acceptedAt: String?
    public let rbacGroupIds: [String]?
}

public struct InviteStatus: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pending = InviteStatus(rawValue: "pending")
    public static let accepted = InviteStatus(rawValue: "accepted")
    public static let expired = InviteStatus(rawValue: "expired")
    public static let deleted = InviteStatus(rawValue: "deleted")
}

/// Request to create a new invitation.
public struct CreateInviteRequest: Sendable, Encodable {
    public let email: String
    public let role: OrganizationRole
    public let rbacGroupIds: [String]?
    public init(email: String, role: OrganizationRole, rbacGroupIds: [String]? = nil) {
        self.email = email
        self.role = role
        self.rbacGroupIds = rbacGroupIds
    }
}

/// Response to an invite delete request.
///
/// Anthropic answers `{"id", "type": "invite_deleted"}`; `deleted` is derived from `type`,
/// and still honours a `deleted` key if one is ever sent.
public struct InviteDeleteResponse: Sendable, Decodable {
    public let id: String
    public let type: String
    public let deleted: Bool

    private enum CodingKeys: String, CodingKey { case id, type, deleted }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? (type == "invite_deleted")
    }
}
