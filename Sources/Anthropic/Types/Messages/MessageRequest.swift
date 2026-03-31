import Foundation

/// A request to create a message via the Anthropic API.
///
/// ```swift
/// let request = MessageRequest(
///     model: .claude4Sonnet,
///     messages: [.user("Hello!")],
///     maxTokens: 1024
/// )
/// ```
public struct MessageRequest: Sendable, Encodable {
    /// The model to use for the request.
    public var model: Model
    /// The conversation messages.
    public var messages: [MessageParam]
    /// The maximum number of tokens to generate.
    public var maxTokens: Int
    /// An optional system prompt.
    public var system: SystemPrompt?
    /// Tools the model may call.
    public var tools: [Tool]?
    /// Specifies how the model should use tools.
    public var toolChoice: ToolChoice?
    /// Optional metadata attached to the request.
    public var metadata: RequestMetadata?
    /// Sequences that cause the model to stop generating.
    public var stopSequences: [String]?
    /// Sampling temperature (0–1).
    public var temperature: Double?
    /// Top-K sampling parameter.
    public var topK: Int?
    /// Top-P sampling parameter.
    public var topP: Double?
    /// Whether to stream the response (set by the SDK, not the user).
    var stream: Bool?

    public init(
        model: Model,
        messages: [MessageParam],
        maxTokens: Int,
        system: SystemPrompt? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        metadata: RequestMetadata? = nil,
        stopSequences: [String]? = nil,
        temperature: Double? = nil,
        topK: Int? = nil,
        topP: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.system = system
        self.tools = tools
        self.toolChoice = toolChoice
        self.metadata = metadata
        self.stopSequences = stopSequences
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
    }
}

// MARK: - System Prompt

/// The system prompt for a message request.
public enum SystemPrompt: Sendable, Encodable {
    /// A plain text system prompt.
    case text(String)
    /// A structured system prompt composed of content blocks.
    case blocks([ContentBlockParam])

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let s):
            var container = encoder.singleValueContainer()
            try container.encode(s)
        case .blocks(let blocks):
            var container = encoder.singleValueContainer()
            try container.encode(blocks)
        }
    }
}

// MARK: - Message Param

/// A message in a conversation (used in requests).
public struct MessageParam: Sendable, Encodable, Equatable {
    public enum Role: String, Sendable, Codable {
        case user
        case assistant
    }

    public let role: Role
    public let content: MessageContent

    public init(role: Role, content: MessageContent) {
        self.role = role
        self.content = content
    }

    // MARK: - Convenience

    /// Creates a user message with a plain text string.
    public static func user(_ text: String) -> MessageParam {
        MessageParam(role: .user, content: .text(text))
    }

    /// Creates an assistant message with a plain text string.
    public static func assistant(_ text: String) -> MessageParam {
        MessageParam(role: .assistant, content: .text(text))
    }

    /// Creates a user message with content blocks.
    public static func user(_ blocks: [ContentBlockParam]) -> MessageParam {
        MessageParam(role: .user, content: .blocks(blocks))
    }

    /// Creates an assistant message with content blocks.
    public static func assistant(_ blocks: [ContentBlockParam]) -> MessageParam {
        MessageParam(role: .assistant, content: .blocks(blocks))
    }
}

/// The content of a message: either a plain string or an array of content blocks.
public enum MessageContent: Sendable, Encodable, Equatable {
    case text(String)
    case blocks([ContentBlockParam])

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let s):
            var container = encoder.singleValueContainer()
            try container.encode(s)
        case .blocks(let blocks):
            var container = encoder.singleValueContainer()
            try container.encode(blocks)
        }
    }
}
