import Foundation

/// A skill object from the Skills API (beta).
public struct Skill: Sendable, Decodable, Equatable {
    public let id: String
    public let type: String
    public let name: String
    public let description: String?
    public let createdAt: String
}

/// Request to create a skill.
public struct CreateSkillRequest: Sendable, Encodable {
    public let name: String
    public let description: String?
    public let parameters: JSONSchema?

    public init(name: String, description: String? = nil, parameters: JSONSchema? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}
