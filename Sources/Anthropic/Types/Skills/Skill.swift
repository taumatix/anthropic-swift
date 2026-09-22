import Foundation

/// Where a ``Skill`` comes from.
///
/// The `type` is modelled as a ``Kind`` for switching, with the raw string kept alongside it so a
/// value Anthropic adds later decodes as ``Kind/unknown`` instead of failing the whole response.
public struct SkillSource: Sendable, Decodable, Equatable {
    /// The source values documented at
    /// <https://platform.claude.com/docs/en/api/skills/list> (retrieved 2026-09-22).
    ///
    /// `unknown` carries the string the API sent, so the mapping is total in both directions and a
    /// value Anthropic adds later can be round-tripped — decoded from a response and sent straight
    /// back as a filter — without this SDK having to know it. Follows `Model`, which is open to
    /// arbitrary strings for the same reason.
    public enum Kind: RawRepresentable, Sendable, Hashable {
        /// Authored by the platform user; private to their workspace.
        case custom
        /// Published by Anthropic; shared and read-only.
        case anthropic
        /// An Anthropic-published sample skill.
        case anthropicExample
        /// Resolved from an installed plugin.
        case plugin
        /// A source this SDK version does not know, with the value the API sent.
        case unknown(String)

        /// The four sources documented today. `unknown` is excluded: it has no fixed value.
        public static let documented: [Kind] = [.custom, .anthropic, .anthropicExample, .plugin]

        public init(rawValue: String) {
            switch rawValue {
            case "custom": self = .custom
            case "anthropic": self = .anthropic
            case "anthropic_example": self = .anthropicExample
            case "plugin": self = .plugin
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .custom: return "custom"
            case .anthropic: return "anthropic"
            case .anthropicExample: return "anthropic_example"
            case .plugin: return "plugin"
            case .unknown(let raw): return raw
            }
        }
    }

    /// The source. ``Kind/unknown(_:)`` if the API returned a value this SDK predates.
    public let type: Kind

    /// The `type` string exactly as the API returned it.
    public var rawType: String { type.rawValue }

    public init(type: Kind) {
        self.type = type
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = Kind(rawValue: try container.decode(String.self, forKey: .type))
    }
}

/// A skill object from the Skills API.
///
/// Decoded from the object documented at
/// <https://platform.claude.com/docs/en/api/skills/retrieve> (retrieved 2026-09-22). The same shape
/// is returned whether or not `anthropic-beta: skills-2025-10-02` is sent.
///
/// Every field the API added after this SDK's first Skills release is optional, so a response that
/// omits one decodes rather than throwing.
public struct Skill: Sendable, Decodable, Equatable {
    /// Unique identifier for the skill.
    public let id: String
    /// Object type. Always `"skill"`.
    public let type: String
    /// Human-readable, single-line label for the skill. Maximum 255 characters, not unique.
    public let displayName: String
    /// ID of the newest skill version — what a `latest` reference resolves to.
    ///
    /// `nil` only if the API omitted it; the documentation says a skill always holds one version.
    public let latestVersionId: String?
    /// Where the skill comes from.
    public let source: SkillSource?
    /// ISO 8601 timestamp of when the skill was created.
    public let createdAt: String
    /// ISO 8601 timestamp of when the skill was last updated.
    public let updatedAt: String?
    /// Free-text description.
    ///
    /// The documented object carries no description; this is `nil` against the current API and is
    /// retained so a response that does supply one is not discarded.
    public let description: String?

    /// The skill's label.
    ///
    /// - Note: Renamed. The API calls this field `display_name`; use ``displayName``.
    @available(*, deprecated, renamed: "displayName")
    public var name: String { displayName }

    private enum CodingKeys: String, CodingKey {
        case id, type, displayName, latestVersionId, source, createdAt, updatedAt, description
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "skill"
        // `display_name` is the documented key. `name` is the pre-GA key this SDK shipped against;
        // accepting it keeps an older deployment decodable.
        if let displayName = try container.decodeIfPresent(String.self, forKey: .displayName) {
            self.displayName = displayName
        } else {
            self.displayName = try container.decode(String.self, forKey: .name)
        }
        self.latestVersionId = try container.decodeIfPresent(String.self, forKey: .latestVersionId)
        self.source = try container.decodeIfPresent(SkillSource.self, forKey: .source)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

/// The response returned by ``SkillsService/delete(id:)``.
///
/// Documented at <https://platform.claude.com/docs/en/api/skills/delete> (retrieved 2026-09-22).
/// Named to match `FileDeleteResponse`, `BatchDeleteResponse` and `InviteDeleteResponse`.
///
/// Both fields are required. Defaulting `type` would let any `200` carrying an `id` decode as a
/// confirmed deletion, and a caller who only checks "did it throw" would be told a delete happened
/// that did not.
public struct SkillDeleteResponse: Sendable, Decodable, Equatable {
    /// Unique identifier for the deleted skill.
    public let id: String
    /// Deleted object type. Always `"skill_deleted"`.
    public let type: String
}

/// Request to create a skill.
///
/// - Warning: The Skills API creates a skill from an uploaded file set, not from a JSON body — see
///   <https://platform.claude.com/docs/en/api/skills/create>. This type encodes a JSON body the API
///   does not accept and never did; it is retained only so existing call sites still compile.
///   Use ``SkillsService/create(files:displayName:)``.
@available(*, deprecated, message: "The API creates skills from uploaded files. Use SkillsService.create(files:displayName:).")
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
