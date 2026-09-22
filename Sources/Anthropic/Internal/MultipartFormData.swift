import Foundation

/// Builds `multipart/form-data` request bodies.
///
/// Used by `FilesService` for file uploads.
struct MultipartFormData: Sendable {
    /// A single part of the multipart body.
    struct Part: Sendable {
        let name: String
        let filename: String?
        let contentType: String
        let data: Data
    }

    let boundary: String
    private(set) var parts: [Part] = []

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    mutating func append(_ part: Part) {
        parts.append(part)
    }

    /// Builds the complete `multipart/form-data` body as `Data`.
    func build() -> Data {
        var body = Data()
        let crlf = "\r\n"

        for part in parts {
            body.append("--\(boundary)\(crlf)")

            var disposition = "Content-Disposition: form-data; name=\"\(Self.escapeHeaderValue(part.name))\""
            if let filename = part.filename {
                disposition += "; filename=\"\(Self.escapeHeaderValue(filename))\""
            }
            body.append("\(disposition)\(crlf)")
            body.append("Content-Type: \(part.contentType)\(crlf)")
            body.append(crlf)
            body.append(part.data)
            body.append(crlf)
        }

        body.append("--\(boundary)--\(crlf)")
        return body
    }

    /// The value for the `Content-Type` header, including the boundary.
    var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Makes a string safe to sit inside a quoted `Content-Disposition` parameter.
    ///
    /// A part name or filename can come from the caller — `SkillFile.path` does — and an
    /// unescaped `"` or CRLF there lets that value close the quoted string and forge further part
    /// headers or a whole extra part. Per RFC 7578 §5.1 and RFC 6266, backslash-escape the quoting
    /// characters and drop the line breaks that would end the header.
    /// Iterates unicode scalars, not `Character`s: CRLF is a *single* grapheme cluster in Swift, so
    /// a `Character` comparison against "\r" and "\n" matches neither and lets the pair through.
    static func escapeHeaderValue(_ value: String) -> String {
        var escaped = String.UnicodeScalarView()
        escaped.reserveCapacity(value.unicodeScalars.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\r", "\n":
                continue
            case "\"", "\\":
                escaped.append("\\")
                escaped.append(scalar)
            default:
                escaped.append(scalar)
            }
        }
        return String(escaped)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
