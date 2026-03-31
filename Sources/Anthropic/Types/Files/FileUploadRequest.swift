import Foundation

/// Parameters for uploading a file to the Files API.
public struct FileUploadRequest: Sendable {
    public let content: Data
    public let filename: String
    public let mimeType: String

    public init(content: Data, filename: String, mimeType: String) {
        self.content = content
        self.filename = filename
        self.mimeType = mimeType
    }
}
