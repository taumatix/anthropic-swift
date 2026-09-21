import Foundation

/// Provides access to the Files API.
///
/// Access via `AnthropicClient.files`.
///
/// - Note: This service sends `anthropic-beta: files-api-2025-04-14`, which the Files API no longer
///   requires — it left beta, and as of 2026-09-21 the header is optional. Sending it still works
///   and keeps the beta response shapes, so the cost is missing surface: no `expires_at` on a file,
///   no `expires_in_seconds` at upload, and the superseded `before_id`/`after_id` cursor instead of
///   `page`/`next_page`. Migration is tracked in `ROADMAP.md`.
public final class FilesService: Sendable {
    private let pipeline: RequestPipeline
    private let betaHeader = "files-api-2025-04-14"

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Upload

    /// Uploads a file and returns the resulting `FileObject`.
    ///
    /// - Parameters:
    ///   - content: The file data to upload.
    ///   - filename: The original filename (used for display and content-type detection).
    ///   - mimeType: The MIME type of the file (e.g., `"application/pdf"`, `"text/plain"`).
    public func upload(content: Data, filename: String, mimeType: String) async throws -> FileObject {
        var form = MultipartFormData()
        form.append(.init(name: "file", filename: filename, contentType: mimeType, data: content))

        var request = HTTPRequest(method: "POST", path: "/v1/files")
        request.headers["content-type"] = form.contentTypeHeader
        request.headers["anthropic-beta"] = betaHeader
        request.body = form.build()
        return try await pipeline.send(request)
    }

    // MARK: - List

    /// Returns a paginated list of uploaded files.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<FileObject> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }

        var request = HTTPRequest(method: "GET", path: "/v1/files", queryItems: queryItems)
        request.headers["anthropic-beta"] = betaHeader
        let page: Page<FileObject> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    // MARK: - Get Metadata

    /// Returns metadata for a specific file.
    ///
    /// - Parameter id: The file identifier.
    public func get(id: String) async throws -> FileObject {
        var request = HTTPRequest(method: "GET", path: "/v1/files/\(id)")
        request.headers["anthropic-beta"] = betaHeader
        return try await pipeline.send(request)
    }

    // MARK: - Delete

    /// Deletes a file.
    ///
    /// - Parameter id: The file identifier.
    public func delete(id: String) async throws -> FileDeleteResponse {
        var request = HTTPRequest(method: "DELETE", path: "/v1/files/\(id)")
        request.headers["anthropic-beta"] = betaHeader
        return try await pipeline.send(request)
    }

    // MARK: - Download

    /// Downloads the content of a file.
    ///
    /// - Parameter id: The file identifier.
    /// - Returns: The raw file data.
    public func download(id: String) async throws -> Data {
        var request = HTTPRequest(method: "GET", path: "/v1/files/\(id)/content")
        request.headers["anthropic-beta"] = betaHeader
        let response = try await pipeline.sendRaw(request)
        return response.body
    }

    // MARK: - Pagination

    private func attachFetcher(to page: Page<FileObject>) -> Page<FileObject> {
        let pipeline = self.pipeline
        let betaHeader = self.betaHeader
        return Page(
            data: page.data,
            hasMore: page.hasMore,
            firstId: page.firstId,
            lastId: page.lastId,
            nextPageFetcher: { afterId in
                var request = HTTPRequest(
                    method: "GET",
                    path: "/v1/files",
                    queryItems: [URLQueryItem(name: "after_id", value: afterId)]
                )
                request.headers["anthropic-beta"] = betaHeader
                let nextPage: Page<FileObject> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
