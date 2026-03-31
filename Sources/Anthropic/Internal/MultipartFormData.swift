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

            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
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
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
