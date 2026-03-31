import Foundation

/// A member of the organization.
public struct OrganizationMember: Sendable, Decodable, Equatable {
    public let userId: String
    public let type: String
    public let organizationRole: OrganizationRole
    public let email: String
    public let name: String
    public let addedAt: String
}

public struct OrganizationRole: RawRepresentable, Sendable, Codable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let user = OrganizationRole(rawValue: "user")
    public static let admin = OrganizationRole(rawValue: "admin")
    public static let billing = OrganizationRole(rawValue: "billing")
}

/// Request to update a member's role.
public struct UpdateMemberRequest: Sendable, Encodable {
    public let organizationRole: OrganizationRole
    public init(organizationRole: OrganizationRole) {
        self.organizationRole = organizationRole
    }
}
