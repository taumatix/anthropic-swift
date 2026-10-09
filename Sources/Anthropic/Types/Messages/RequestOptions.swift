import Foundation

/// A prompt-cache breakpoint. Read from the Messages reference on 2026-10-09; the model-by-model rules
/// for what is cacheable are the API's, not checked here.
public struct CacheControl: Sendable, Codable, Equatable {
    /// How long a cached prefix is kept.
    public enum TTL: String, Sendable, Codable, Equatable {
        case fiveMinutes = "5m"
        case oneHour = "1h"
    }

    public var ttl: TTL?

    /// An ephemeral breakpoint. `nil` leaves the TTL to the API's default (5 minutes).
    public init(ttl: TTL? = nil) { self.ttl = ttl }

    private enum CodingKeys: String, CodingKey { case type, ttl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ttl = try c.decodeIfPresent(TTL.self, forKey: .ttl)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("ephemeral", forKey: .type)
        try c.encodeIfPresent(ttl, forKey: .ttl)
    }
}

/// Which capacity tier a request may use.
public enum ServiceTier: String, Sendable, Codable, Equatable {
    /// Use priority capacity when there is any.
    case auto
    /// Never use priority capacity.
    case standardOnly = "standard_only"
}

/// How much effort the model applies, and the shape of its output.
public struct OutputConfig: Sendable, Encodable, Equatable {
    /// How thorough, and how slow, the answer is.
    public enum Effort: String, Sendable, Codable, Equatable {
        case low, medium, high, xhigh, max
    }

    public var effort: Effort?
    /// A JSON Schema the answer must follow (structured outputs).
    public var jsonSchema: JSONSchema?

    public init(effort: Effort? = nil, jsonSchema: JSONSchema? = nil) {
        self.effort = effort
        self.jsonSchema = jsonSchema
    }

    private enum CodingKeys: String, CodingKey { case effort, format }
    private struct Format: Encodable {
        let type = "json_schema"
        let schema: JSONSchema
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(effort, forKey: .effort)
        if let jsonSchema { try c.encode(Format(schema: jsonSchema), forKey: .format) }
    }
}
