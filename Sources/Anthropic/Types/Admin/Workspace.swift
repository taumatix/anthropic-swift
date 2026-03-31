import Foundation

/// An organization workspace.
public struct Workspace: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
    public let name: String
    public let createdAt: String
    public let archivedAt: String?
    public let displayColor: String?
}

/// Request to create a new workspace.
public struct CreateWorkspaceRequest: Sendable, Encodable {
    public let name: String
    public init(name: String) { self.name = name }
}
