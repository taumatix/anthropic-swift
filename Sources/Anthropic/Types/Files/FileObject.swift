import Foundation

/// A file object from the Files API (beta).
public struct FileObject: Sendable, Decodable, Equatable {
    /// The unique file identifier.
    public let id: String
    /// Always `"file"`.
    public let type: String
    /// The original filename provided at upload.
    public let filename: String
    /// File size in bytes.
    public let size: Int
    /// Unix timestamp when the file was created.
    public let createdAt: Int
    /// The purpose of the file.
    public let purpose: String
}

/// Response to a file delete request.
public struct FileDeleteResponse: Sendable, Decodable {
    public let id: String
    public let type: String
    public let deleted: Bool
}
