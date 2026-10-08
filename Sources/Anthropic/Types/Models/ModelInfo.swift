import Foundation

/// Information about a Claude model returned by the Models API.
///
/// Shape per <https://platform.claude.com/docs/en/api/models> (retrieved 2026-10-09). Every field
/// added after `displayName` is optional, so a body that omits it still decodes.
public struct ModelInfo: Sendable, Decodable, Equatable {
    /// Always `"model"`.
    public let type: String
    /// The model identifier (e.g., `"claude-opus-4-5"`).
    public let id: String
    /// The human-readable display name.
    public let displayName: String
    /// RFC 3339 timestamp of the model's release; an epoch value when the date is unknown.
    public let createdAt: String
    /// What the model supports. `nil` when the API serves `null`.
    public let capabilities: ModelCapabilities?
    /// `"active"`, `"deprecated"` or `"retired"`. A `String` so a new stage decodes rather than fails.
    public let lifecycle: String?
    /// The model line (`"haiku"`, `"sonnet"`, `"opus"`, `"fable"`, `"mythos"`, ...), or `nil` when it
    /// belongs to none. Do not infer a line from `id`; more lines may be added.
    public let line: String?
    /// RFC 3339 timestamp of the model's most recent deprecation; `nil` while `active`.
    public let deprecatedAt: String?
    /// RFC 3339 timestamp of the scheduled retirement; `nil` while `active` or unscheduled. A past
    /// date on a `deprecated` model means retirement is overdue, not done: `lifecycle` is the signal.
    public let retiresAt: String?
    /// Maximum input context window in tokens.
    public let maxInputTokens: Int?
    /// Maximum value of the `max_tokens` request parameter for this model.
    public let maxTokens: Int?

    init(
        type: String, id: String, displayName: String, createdAt: String,
        capabilities: ModelCapabilities? = nil, lifecycle: String? = nil, line: String? = nil,
        deprecatedAt: String? = nil, retiresAt: String? = nil,
        maxInputTokens: Int? = nil, maxTokens: Int? = nil
    ) {
        self.type = type
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.capabilities = capabilities
        self.lifecycle = lifecycle
        self.line = line
        self.deprecatedAt = deprecatedAt
        self.retiresAt = retiresAt
        self.maxInputTokens = maxInputTokens
        self.maxTokens = maxTokens
    }
}

/// Whether a single capability is supported.
public struct CapabilitySupport: Sendable, Decodable, Equatable {
    public let supported: Bool
}

/// Capability names mapped to their support details.
public struct ModelCapabilities: Sendable, Decodable, Equatable {
    public let batch: CapabilitySupport?
    public let citations: CapabilitySupport?
    /// Whether code run in the code execution tool can call the request's other tools. Support for
    /// the tool itself is `serverTools.codeExecution`.
    public let codeExecution: CapabilitySupport?
    public let contextManagement: ContextManagement?
    public let effort: Effort?
    public let imageInput: CapabilitySupport?
    public let pdfInput: CapabilitySupport?
    public let serverTools: ServerTools?
    public let structuredOutputs: CapabilitySupport?
    public let thinking: Thinking?

    public struct ContextManagement: Sendable, Decodable, Equatable {
        public let supported: Bool
        public let clearThinking20251015: CapabilitySupport?
        public let clearToolUses20250919: CapabilitySupport?
        public let compact20260112: CapabilitySupport?
    }

    public struct Effort: Sendable, Decodable, Equatable {
        public let supported: Bool
        public let low: CapabilitySupport?
        public let medium: CapabilitySupport?
        public let high: CapabilitySupport?
        public let xhigh: CapabilitySupport?
        public let max: CapabilitySupport?
    }

    public struct ServerTools: Sendable, Decodable, Equatable {
        /// True when the model supports at least one of the tools.
        public let supported: Bool
        public let codeExecution: CapabilitySupport?
        public let webSearch: CapabilitySupport?
    }

    public struct Thinking: Sendable, Decodable, Equatable {
        public let supported: Bool
        public let types: Types?

        /// Which `thinking.type` values the model accepts. Read each key on its own: `enabled` can
        /// be false while `disabled` is true.
        public struct Types: Sendable, Decodable, Equatable {
            public let adaptive: CapabilitySupport?
            public let disabled: CapabilitySupport?
            public let enabled: CapabilitySupport?
        }
    }
}
