import Foundation

/// A tool that the model can call.
public struct Tool: Sendable, Codable, Equatable {
    /// The name of the tool. Must match `[a-zA-Z0-9_-]{1,64}`.
    public let name: String
    /// A description of what the tool does. Used by the model to decide when to call it.
    public let description: String?
    /// The JSON schema for the tool's input parameters.
    public let inputSchema: JSONSchema

    public init(name: String, description: String? = nil, inputSchema: JSONSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// Specifies how the model should use tools.
public enum ToolChoice: Sendable, Codable, Equatable {
    /// The model decides whether to use a tool (default).
    case auto
    /// The model must use at least one tool.
    case any
    /// The model must use the specified tool.
    case tool(name: String)
    /// The model must not use any tools.
    case none

    enum CodingKeys: String, CodingKey {
        case type
        case name
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .any:
            try container.encode("any", forKey: .type)
        case .tool(let name):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        case .none:
            try container.encode("none", forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "auto": self = .auto
        case "any": self = .any
        case "none": self = .none
        case "tool":
            let name = try container.decode(String.self, forKey: .name)
            self = .tool(name: name)
        default: self = .auto
        }
    }
}

/// A JSON Schema definition for tool input parameters.
///
/// Supports a subset of JSON Schema draft 7 sufficient for tool definitions.
public indirect enum JSONSchema: Sendable, Codable, Equatable {
    case object(properties: [String: JSONSchema], required: [String]?, description: String?)
    case array(items: JSONSchema, description: String?)
    case string(enumValues: [String]?, description: String?)
    case number(description: String?)
    case integer(description: String?)
    case boolean(description: String?)
    case null

    // MARK: - Convenience initialisers

    public static func object(properties: [String: JSONSchema], required: [String]? = nil) -> JSONSchema {
        .object(properties: properties, required: required, description: nil)
    }

    public static func string(enum enumValues: [String]? = nil) -> JSONSchema {
        .string(enumValues: enumValues, description: nil)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, properties, required, items, `enum`, description
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .object(let props, let req, let desc):
            try container.encode("object", forKey: .type)
            if let desc = desc { try container.encode(desc, forKey: .description) }
            try container.encode(props, forKey: .properties)
            if let req = req { try container.encode(req, forKey: .required) }
        case .array(let items, let desc):
            try container.encode("array", forKey: .type)
            if let desc = desc { try container.encode(desc, forKey: .description) }
            try container.encode(items, forKey: .items)
        case .string(let enumVals, let desc):
            try container.encode("string", forKey: .type)
            if let desc = desc { try container.encode(desc, forKey: .description) }
            if let enumVals = enumVals { try container.encode(enumVals, forKey: .enum) }
        case .number(let desc):
            try container.encode("number", forKey: .type)
            if let desc = desc { try container.encode(desc, forKey: .description) }
        case .integer(let desc):
            try container.encode("integer", forKey: .type)
            if let desc = desc { try container.encode(desc, forKey: .description) }
        case .boolean(let desc):
            try container.encode("boolean", forKey: .type)
            if let desc = desc { try container.encode(desc, forKey: .description) }
        case .null:
            try container.encode("null", forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeStr = try container.decode(String.self, forKey: .type)
        let desc = try container.decodeIfPresent(String.self, forKey: .description)
        switch typeStr {
        case "object":
            let props = try container.decodeIfPresent([String: JSONSchema].self, forKey: .properties) ?? [:]
            let req = try container.decodeIfPresent([String].self, forKey: .required)
            self = .object(properties: props, required: req, description: desc)
        case "array":
            let items = try container.decode(JSONSchema.self, forKey: .items)
            self = .array(items: items, description: desc)
        case "string":
            let enumVals = try container.decodeIfPresent([String].self, forKey: .enum)
            self = .string(enumValues: enumVals, description: desc)
        case "number": self = .number(description: desc)
        case "integer": self = .integer(description: desc)
        case "boolean": self = .boolean(description: desc)
        default: self = .null
        }
    }
}
