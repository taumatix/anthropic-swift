import Foundation

// MARK: - Content Blocks (Response)

/// A content block returned in a message response.
///
/// The `.unknown` case is mandatory for forward compatibility: new block types
/// introduced by Anthropic will decode to `.unknown` instead of crashing.
///
/// - Important: Never remove the `.unknown` case. Never add `fatalError` or
///   `preconditionFailure` in the Codable implementation.
public enum ContentBlock: Sendable, Codable, Equatable {
    case text(TextBlock)
    case image(ImageBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case document(DocumentBlock)
    case thinking(ThinkingBlock)
    /// Forward-compatibility case: captures block types not yet known to this SDK version.
    case unknown(type: String, rawData: [String: AnyJSONValue])

    // MARK: - Associated value types

    public struct TextBlock: Sendable, Codable, Equatable {
        public let text: String
        public init(text: String) { self.text = text }
    }

    public struct ImageBlock: Sendable, Codable, Equatable {
        public let source: ImageSource
        public init(source: ImageSource) { self.source = source }
    }

    public struct ToolUseBlock: Sendable, Codable, Equatable {
        public let id: String
        public let name: String
        public let input: [String: AnyJSONValue]
        public init(id: String, name: String, input: [String: AnyJSONValue]) {
            self.id = id; self.name = name; self.input = input
        }
    }

    public struct ToolResultBlock: Sendable, Codable, Equatable {
        public let toolUseId: String
        public let content: [ContentBlock]?
        public let isError: Bool?
        public init(toolUseId: String, content: [ContentBlock]? = nil, isError: Bool? = nil) {
            self.toolUseId = toolUseId; self.content = content; self.isError = isError
        }
    }

    public struct DocumentBlock: Sendable, Codable, Equatable {
        public let source: DocumentSource
        public init(source: DocumentSource) { self.source = source }
    }

    public struct ThinkingBlock: Sendable, Codable, Equatable {
        public let thinking: String
        public let signature: String
        public init(thinking: String, signature: String) {
            self.thinking = thinking; self.signature = signature
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "image":
            self = .image(try ImageBlock(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "tool_result":
            self = .toolResult(try ToolResultBlock(from: decoder))
        case "document":
            self = .document(try DocumentBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        default:
            // Decode remaining keys as AnyJSONValue for forward compatibility
            let raw = try [String: AnyJSONValue](from: decoder)
            self = .unknown(type: type_, rawData: raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let block):
            try container.encode("text", forKey: .type)
            try block.encode(to: encoder)
        case .image(let block):
            try container.encode("image", forKey: .type)
            try block.encode(to: encoder)
        case .toolUse(let block):
            try container.encode("tool_use", forKey: .type)
            try block.encode(to: encoder)
        case .toolResult(let block):
            try container.encode("tool_result", forKey: .type)
            try block.encode(to: encoder)
        case .document(let block):
            try container.encode("document", forKey: .type)
            try block.encode(to: encoder)
        case .thinking(let block):
            try container.encode("thinking", forKey: .type)
            try block.encode(to: encoder)
        case .unknown(let type_, let raw):
            try container.encode(type_, forKey: .type)
            try raw.encode(to: encoder)
        }
    }

    // MARK: - Convenience

    /// Returns the text if this is a `.text` block, otherwise `nil`.
    public var text: String? {
        if case .text(let block) = self { return block.text }
        return nil
    }
}

// MARK: - Content Block Params (Request)

/// A content block used in a message request (sent to the API).
public enum ContentBlockParam: Sendable, Codable, Equatable {
    case text(String)
    case image(ImageSource)
    case toolUse(id: String, name: String, input: [String: AnyJSONValue])
    case toolResult(toolUseId: String, content: [ContentBlockParam]?, isError: Bool?)
    case document(DocumentSource)

    private enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, toolUseId, content, isError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let source = try container.decode(ImageSource.self, forKey: .source)
            self = .image(source)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode([String: AnyJSONValue].self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        case "tool_result":
            let id = try container.decode(String.self, forKey: .toolUseId)
            let content = try container.decodeIfPresent([ContentBlockParam].self, forKey: .content)
            let isError = try container.decodeIfPresent(Bool.self, forKey: .isError)
            self = .toolResult(toolUseId: id, content: content, isError: isError)
        case "document":
            let source = try container.decode(DocumentSource.self, forKey: .source)
            self = .document(source)
        default:
            self = .text("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try container.encode("text", forKey: .type)
            try container.encode(t, forKey: .text)
        case .image(let source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let id, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(id, forKey: .toolUseId)
            if let content = content { try container.encode(content, forKey: .content) }
            if let isError = isError { try container.encode(isError, forKey: .isError) }
        case .document(let source):
            try container.encode("document", forKey: .type)
            try container.encode(source, forKey: .source)
        }
    }
}

// MARK: - Supporting Types

/// Image source for image content blocks.
public struct ImageSource: Sendable, Codable, Equatable {
    public enum SourceType: String, Sendable, Codable {
        case base64
        case url
        case file
    }

    public let type: SourceType
    public let mediaType: String?
    public let data: String?
    public let url: String?
    public let fileId: String?

    public static func base64(mediaType: String, data: String) -> ImageSource {
        ImageSource(type: .base64, mediaType: mediaType, data: data, url: nil, fileId: nil)
    }

    public static func url(_ url: String) -> ImageSource {
        ImageSource(type: .url, mediaType: nil, data: nil, url: url, fileId: nil)
    }

    public static func file(id: String) -> ImageSource {
        ImageSource(type: .file, mediaType: nil, data: nil, url: nil, fileId: id)
    }

    private init(type: SourceType, mediaType: String?, data: String?, url: String?, fileId: String?) {
        self.type = type; self.mediaType = mediaType; self.data = data; self.url = url; self.fileId = fileId
    }
}

/// Document source for document content blocks.
public struct DocumentSource: Sendable, Codable, Equatable {
    public enum SourceType: String, Sendable, Codable {
        case base64
        case url
        case file
        case text
    }

    public let type: SourceType
    public let mediaType: String?
    public let data: String?
    public let url: String?
    public let fileId: String?
    public let text: String?

    public static func base64(mediaType: String, data: String) -> DocumentSource {
        DocumentSource(type: .base64, mediaType: mediaType, data: data, url: nil, fileId: nil, text: nil)
    }

    public static func url(_ url: String) -> DocumentSource {
        DocumentSource(type: .url, mediaType: nil, data: nil, url: url, fileId: nil, text: nil)
    }

    public static func file(id: String) -> DocumentSource {
        DocumentSource(type: .file, mediaType: nil, data: nil, url: nil, fileId: id, text: nil)
    }

    public static func text(_ text: String) -> DocumentSource {
        DocumentSource(type: .text, mediaType: nil, data: nil, url: nil, fileId: nil, text: text)
    }

    private init(type: SourceType, mediaType: String?, data: String?, url: String?, fileId: String?, text: String?) {
        self.type = type; self.mediaType = mediaType; self.data = data
        self.url = url; self.fileId = fileId; self.text = text
    }
}

// MARK: - AnyJSONValue

/// A type-erased JSON value for forward-compatible unknown content blocks.
///
/// - Important: This uses `@unchecked Sendable` because it wraps heterogeneous
///   Foundation JSON types. Safety is guaranteed because JSONSerialization only
///   produces thread-safe value types (NSString, NSNumber, NSArray, NSDictionary, NSNull).
public struct AnyJSONValue: @unchecked Sendable, Codable, Equatable {
    // @unchecked Sendable: JSONSerialization only produces thread-safe Foundation value types
    // (NSString, NSNumber, NSArray, NSDictionary, NSNull) — no mutable state involved.
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(Bool.self) { value = v; return }
        if let v = try? container.decode([String: AnyJSONValue].self) { value = v; return }
        if let v = try? container.decode([AnyJSONValue].self) { value = v; return }
        if container.decodeNil() { value = NSNull(); return }
        value = NSNull()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Bool: try container.encode(v)
        case let v as [String: AnyJSONValue]: try container.encode(v)
        case let v as [AnyJSONValue]: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    public static func == (lhs: AnyJSONValue, rhs: AnyJSONValue) -> Bool {
        // Simple structural equality for testing
        switch (lhs.value, rhs.value) {
        case (let l as String, let r as String): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Bool, let r as Bool): return l == r
        case (is NSNull, is NSNull): return true
        default: return false
        }
    }
}
