import Foundation

// MARK: - Stream Events

/// An event in a streaming message response.
public enum MessageStreamEvent: Sendable {
    case messageStart(MessageStartEvent)
    case messageDelta(MessageDeltaEvent)
    case messageStop
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop(index: Int)
    case ping
    case error(StreamErrorEvent)
    /// Forward-compatibility case for unknown event types.
    case unknown(type: String)
}

// MARK: - Event Payloads

public struct MessageStartEvent: Sendable, Decodable {
    public let message: MessageStartData
}

public struct MessageStartData: Sendable, Decodable {
    public let id: String
    public let type: String
    public let role: String
    public let model: Model
    public let usage: Usage
}

public struct MessageDeltaEvent: Sendable, Decodable {
    public let delta: MessageDelta
    public let usage: UsageDelta
}

public struct MessageDelta: Sendable, Decodable {
    public let stopReason: StopReason?
    public let stopSequence: String?
}

public struct ContentBlockStartEvent: Sendable, Decodable {
    public let index: Int
    public let contentBlock: ContentBlockStart
}

/// The initial content block data at the start of a block.
public enum ContentBlockStart: Sendable, Decodable {
    case text(TextBlockStart)
    case toolUse(ToolUseBlockStart)
    case unknown(type: String)

    public struct TextBlockStart: Sendable, Decodable {
        public let text: String
    }

    public struct ToolUseBlockStart: Sendable, Decodable {
        public let id: String
        public let name: String
    }

    private enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "text":   self = .text(try TextBlockStart(from: decoder))
        case "tool_use": self = .toolUse(try ToolUseBlockStart(from: decoder))
        default:       self = .unknown(type: type_)
        }
    }
}

public struct ContentBlockDeltaEvent: Sendable, Decodable {
    public let index: Int
    public let delta: ContentBlockDelta
}

/// A delta update to a content block.
public enum ContentBlockDelta: Sendable, Decodable {
    /// A text delta.
    case textDelta(text: String)
    /// A partial JSON delta for tool input.
    case inputJSONDelta(partialJSON: String)
    /// Forward compatibility.
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey { case type, text, partialJson }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "text_delta":
            let text = try container.decode(String.self, forKey: .text)
            self = .textDelta(text: text)
        case "input_json_delta":
            let json = try container.decode(String.self, forKey: .partialJson)
            self = .inputJSONDelta(partialJSON: json)
        default:
            self = .unknown(type: type_)
        }
    }
}

public struct ContentBlockStopEvent: Sendable, Decodable {
    public let index: Int
}

public struct StreamErrorEvent: Sendable, Decodable {
    public let error: StreamErrorDetail
}

public struct StreamErrorDetail: Sendable, Decodable {
    public let type: String
    public let message: String
}
