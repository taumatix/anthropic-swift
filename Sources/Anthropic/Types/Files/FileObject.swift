import Foundation

/// A file object from the Files API.
///
/// Decoded from the `FileMetadata` object documented at
/// <https://platform.claude.com/docs/en/api/files/retrieve_metadata> (retrieved 2026-10-09):
/// `created_at` is an RFC 3339 string, the size is `size_bytes`, and `mime_type`, `downloadable`
/// and `expires_at` are part of the object.
///
/// The fields this SDK first shipped — an integer `created_at`, `size`, `purpose` — were never in
/// that body, so a documented response could not decode at all. They stay readable (``createdAt``,
/// ``size``, ``purpose``) and a response in the old shape still decodes.
public struct FileObject: Sendable, Decodable, Equatable {
    /// The unique file identifier.
    public let id: String
    /// Always `"file"`.
    public let type: String
    /// The original filename provided at upload.
    public let filename: String
    /// File size in bytes.
    public let size: Int
    /// When the file was created, as the API sent it: an RFC 3339 string such as
    /// `2025-04-15T18:37:24.100435Z`.
    public let createdAtString: String?
    /// Unix timestamp (seconds) when the file was created. `0` if the API sent a string this SDK
    /// cannot parse; ``createdAtString`` then still holds it.
    public let createdAt: Int
    /// The purpose of the file. The documented object has no such field, so this is empty
    /// against the current API.
    @available(*, deprecated, message: "The Files API does not return a purpose.")
    public var purpose: String { _purpose }
    private let _purpose: String

    /// MIME type of the file. `nil` only in the pre-GA shape, which did not carry one.
    public let mimeType: String?
    /// Whether the file's content can be downloaded. The API documents a default of `false`.
    public let downloadable: Bool
    /// RFC 3339 time at which the file expires and its bytes become unavailable, or `nil` if it
    /// does not expire.
    public let expiresAt: String?

    /// File size in bytes (`size_bytes`). Same value as ``size``.
    public var sizeBytes: Int { size }

    private enum CodingKeys: String, CodingKey {
        case id, type, filename, size, sizeBytes, createdAt, purpose, mimeType, downloadable, expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "file"
        self.filename = try container.decode(String.self, forKey: .filename)
        if let bytes = try container.decodeIfPresent(Int.self, forKey: .sizeBytes) {
            self.size = bytes
        } else {
            self.size = try container.decode(Int.self, forKey: .size)
        }
        if let seconds = try? container.decode(Int.self, forKey: .createdAt) {
            self.createdAt = seconds
            self.createdAtString = nil
        } else {
            let raw = try container.decode(String.self, forKey: .createdAt)
            self.createdAtString = raw
            self.createdAt = Self.unixSeconds(rfc3339: raw) ?? 0
        }
        self._purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        self.downloadable = try container.decodeIfPresent(Bool.self, forKey: .downloadable) ?? false
        self.expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
    }

    private static func unixSeconds(rfc3339: String) -> Int? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: rfc3339) ?? plain.date(from: rfc3339) else { return nil }
        return Int(date.timeIntervalSince1970)
    }
}

/// Response to a file delete request.
///
/// Documented at <https://platform.claude.com/docs/en/api/files/delete> (retrieved 2026-10-09):
/// `{"id": "...", "type": "file_deleted"}`. There is no `deleted` field in that body.
public struct FileDeleteResponse: Sendable, Decodable {
    public let id: String
    /// `"file_deleted"`.
    public let type: String
    /// `true` when the API confirmed the deletion: the type is `file_deleted`, or the response said
    /// `deleted: true` (the shape this SDK first assumed).
    public let deleted: Bool

    private enum CodingKeys: String, CodingKey { case id, type, deleted }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? (type == "file_deleted")
    }
}
