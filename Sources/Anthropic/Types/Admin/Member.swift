import Foundation

/// A member of the organization.
public struct OrganizationMember: Sendable, Decodable, Equatable {
    public let userId: String
    public let type: String
    public let organizationRole: OrganizationRole
    public let email: String
    public let name: String
    public let addedAt: String

    private enum CodingKeys: String, CodingKey {
        case id, userId, type, role, organizationRole, email, name, addedAt
    }

    /// Anthropic's user object carries `id` and `role`; `user_id` and `organization_role`
    /// are the names this type used before it was checked against the published bodies,
    /// and are still read when present.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try c.decodeIfPresent(String.self, forKey: .id) {
            userId = id
        } else {
            userId = try c.decode(String.self, forKey: .userId)
        }
        type = try c.decode(String.self, forKey: .type)
        if let role = try c.decodeIfPresent(OrganizationRole.self, forKey: .role) {
            organizationRole = role
        } else {
            organizationRole = try c.decode(OrganizationRole.self, forKey: .organizationRole)
        }
        email = try c.decode(String.self, forKey: .email)
        name = try c.decode(String.self, forKey: .name)
        addedAt = try c.decode(String.self, forKey: .addedAt)
    }
}

public struct OrganizationRole: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let user = OrganizationRole(rawValue: "user")
    public static let admin = OrganizationRole(rawValue: "admin")
    public static let billing = OrganizationRole(rawValue: "billing")
    public static let developer = OrganizationRole(rawValue: "developer")
    public static let claudeCodeUser = OrganizationRole(rawValue: "claude_code_user")
    public static let managed = OrganizationRole(rawValue: "managed")
    public static let membershipAdmin = OrganizationRole(rawValue: "membership_admin")
    public static let owner = OrganizationRole(rawValue: "owner")
    public static let primaryOwner = OrganizationRole(rawValue: "primary_owner")
}

/// Request to update a member's role.
public struct UpdateMemberRequest: Sendable, Encodable {
    public let organizationRole: OrganizationRole
    public init(organizationRole: OrganizationRole) {
        self.organizationRole = organizationRole
    }

    private enum CodingKeys: String, CodingKey { case organizationRole = "role" }
}
