import Foundation

/// One version of a ``Skill``.
///
/// Decoded from the object documented at
/// <https://platform.claude.com/docs/en/api/skills/versions/retrieve> (retrieved 2026-10-09). The
/// list endpoint returns the same object in its `data` array.
///
/// - Note: `name` and `description` describe the *skill* as that version's `SKILL.md` declared it;
///   `name` is the skill's immutable kebab-case slug, not a display label (that is
///   ``Skill/displayName``).
public struct SkillVersion: Sendable, Decodable, Equatable {
    /// Unique identifier for this version. It addresses the version in paths and pins it in
    /// references.
    public let id: String
    /// Object type. Always `"skill_version"`.
    public let type: String
    /// ID of the skill this is a version of.
    public let skillId: String
    /// The skill's immutable kebab-case slug, taken from the first upload's `SKILL.md` frontmatter.
    /// `nil` only if the API omitted it; the documentation says it is always set.
    public let name: String?
    /// Description extracted from this version's `SKILL.md`. `nil` only if the API omitted it.
    public let description: String?
    /// ISO 8601 timestamp of when the version was created.
    public let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id, type, skillId, name, description, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "skill_version"
        self.skillId = try container.decode(String.self, forKey: .skillId)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

/// The response to deleting a skill version.
///
/// Decoded from the body documented at
/// <https://platform.claude.com/docs/en/api/skills/versions/delete> (retrieved 2026-10-09).
public struct DeletedSkillVersion: Sendable, Decodable, Equatable {
    /// Unique identifier of the deleted version.
    public let id: String
    /// Deleted object type. Always `"skill_version_deleted"`.
    public let type: String
}

/// Which version of a skill to address: a specific version ID, or the newest.
///
/// A string literal is a version ID, except `"latest"`, which is the API's own spelling of
/// ``latest``.
public enum SkillVersionReference: Sendable, Hashable, ExpressibleByStringLiteral {
    /// The skill's most recent version — the API's literal `latest`.
    case latest
    /// A specific version, by the ID a ``SkillVersion`` or ``Skill/latestVersionId`` carries.
    case id(String)

    public init(stringLiteral value: String) {
        self = value == "latest" ? .latest : .id(value)
    }

    /// The path segment the API expects.
    var pathValue: String {
        switch self {
        case .latest: return "latest"
        case .id(let id): return id
        }
    }
}
