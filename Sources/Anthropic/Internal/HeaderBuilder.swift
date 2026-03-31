import Foundation

/// Utility for building and merging HTTP headers.
enum HeaderBuilder {
    /// Merges additional headers into a base dictionary.
    /// Values in `additional` override values in `base` for the same key.
    static func merge(base: [String: String], additional: [String: String]) -> [String: String] {
        base.merging(additional) { _, new in new }
    }

    /// Appends a value to a comma-separated header (e.g., `anthropic-beta`).
    static func append(value: String, toHeader header: String, in headers: inout [String: String]) {
        if let existing = headers[header], !existing.isEmpty {
            headers[header] = "\(existing),\(value)"
        } else {
            headers[header] = value
        }
    }
}
