import Foundation

/// An organization workspace.
public struct Workspace: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
    public let name: String
    public let createdAt: String
    public let archivedAt: String?
    public let displayColor: String?
    public let compartmentId: String?
    public let externalKeyId: String?
    public let tags: [String: String]?
    public let dataResidency: WorkspaceDataResidency?
}

/// A workspace's data residency configuration.
public struct WorkspaceDataResidency: Sendable, Decodable, Equatable {
    /// `"unrestricted"` or a list of geos, kept as the strings Anthropic sends.
    public let allowedInferenceGeos: [String]?
    public let allowsAllInferenceGeos: Bool
    public let defaultInferenceGeo: String?
    public let workspaceGeo: String?

    private enum CodingKeys: String, CodingKey {
        case allowedInferenceGeos, defaultInferenceGeo, workspaceGeo
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? c.decode([String].self, forKey: .allowedInferenceGeos) {
            allowedInferenceGeos = list
            allowsAllInferenceGeos = false
        } else {
            let single = try c.decodeIfPresent(String.self, forKey: .allowedInferenceGeos)
            allowedInferenceGeos = nil
            allowsAllInferenceGeos = (single == "unrestricted")
        }
        defaultInferenceGeo = try c.decodeIfPresent(String.self, forKey: .defaultInferenceGeo)
        workspaceGeo = try c.decodeIfPresent(String.self, forKey: .workspaceGeo)
    }
}

/// Request to create a new workspace.
public struct CreateWorkspaceRequest: Sendable, Encodable {
    public let name: String
    public let displayColor: String?
    public let externalKeyId: String?
    public let tags: [String: String]?
    public init(name: String, displayColor: String? = nil, externalKeyId: String? = nil, tags: [String: String]? = nil) {
        self.name = name
        self.displayColor = displayColor
        self.externalKeyId = externalKeyId
        self.tags = tags
    }
}
