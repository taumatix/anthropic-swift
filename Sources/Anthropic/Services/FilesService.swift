import Foundation

/// Provides access to the Files API.
///
/// Access via `AnthropicClient.files`.
///
/// - Note: Targets the GA Files API and sends no `anthropic-beta` header. `files-api-2025-04-14`
///   is optional now, and sending it keeps the superseded list envelope (`has_more`, `before_id`,
///   `after_id`) that ignores the `page` token this service sends. Callers who need the beta shapes
///   can set the header with `ClientOptions.additionalHeaders`.
public final class FilesService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    private static func encoded(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? id
    }

    // MARK: - Upload

    /// Uploads a file and returns the resulting `FileObject`.
    ///
    /// - Parameters:
    ///   - content: The file data to upload.
    ///   - filename: The original filename (used for display and content-type detection).
    ///   - mimeType: The MIME type of the file (e.g., `"application/pdf"`, `"text/plain"`).
    ///   - expiresInSeconds: Seconds from upload until the file expires and its bytes become
    ///     unavailable. The API accepts 3600 (one hour) to 7776000 (ninety days); a value outside
    ///     that range is passed through and rejected by the server. `nil` sets no expiry.
    public func upload(
        content: Data,
        filename: String,
        mimeType: String,
        expiresInSeconds: Int? = nil
    ) async throws -> FileObject {
        var form = MultipartFormData()
        form.append(.init(name: "file", filename: filename, contentType: mimeType, data: content))
        if let expiresInSeconds = expiresInSeconds {
            form.append(.init(name: "expires_in_seconds", filename: nil, contentType: "text/plain", data: Data("\(expiresInSeconds)".utf8)))
        }

        var request = HTTPRequest(method: "POST", path: "/v1/files")
        request.headers["content-type"] = form.contentTypeHeader
        request.body = form.build()
        return try await pipeline.send(request)
    }

    // MARK: - List

    /// Returns a paginated list of uploaded files.
    ///
    /// The returned ``Page`` follows `next_page` as items are consumed.
    ///
    /// - Parameters:
    ///   - limit: Results per page. The API accepts 1...1000 and defaults to 20.
    ///   - pageToken: A ``Page/nextPageToken`` from a previous response. `nil` returns the first page.
    public func list(limit: Int? = nil, pageToken: String? = nil) async throws -> Page<FileObject> {
        let page: Page<FileObject> = try await pipeline.send(listRequest(limit: limit, pageToken: pageToken))
        return attachFetcher(to: page, limit: limit)
    }

    /// Returns a paginated list of uploaded files.
    ///
    /// - Note: Pages by file id, which the API replaced with `page`/`next_page`. Kept so existing
    ///   call sites compile; iteration over the result stops after one page.
    @available(*, deprecated, message: "The Files API paginates by token. Use list(limit:pageToken:).")
    public func list(limit: Int? = nil, afterId: String?, beforeId: String? = nil) async throws -> Page<FileObject> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        var request = HTTPRequest(method: "GET", path: "/v1/files", queryItems: queryItems)
        return try await pipeline.send(request)
    }

    private func listRequest(limit: Int?, pageToken: String?) -> HTTPRequest {
        Self.listRequest(limit: limit, pageToken: pageToken)
    }

    private static func listRequest(limit: Int?, pageToken: String?) -> HTTPRequest {
        var queryItems: [URLQueryItem] = []
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let pageToken = pageToken { queryItems.append(URLQueryItem(name: "page", value: pageToken)) }
        var request = HTTPRequest(method: "GET", path: "/v1/files", queryItems: queryItems)
        return request
    }

    // MARK: - Get Metadata

    /// Returns metadata for a specific file.
    ///
    /// - Parameter id: The file identifier.
    public func get(id: String) async throws -> FileObject {
        var request = HTTPRequest(method: "GET", path: "/v1/files/\(Self.encoded(id))")
        return try await pipeline.send(request)
    }

    // MARK: - Delete

    /// Deletes a file.
    ///
    /// - Parameter id: The file identifier.
    public func delete(id: String) async throws -> FileDeleteResponse {
        var request = HTTPRequest(method: "DELETE", path: "/v1/files/\(Self.encoded(id))")
        return try await pipeline.send(request)
    }

    // MARK: - Download

    /// Downloads the content of a file.
    ///
    /// - Parameter id: The file identifier.
    /// - Returns: The raw file data.
    public func download(id: String) async throws -> Data {
        var request = HTTPRequest(method: "GET", path: "/v1/files/\(Self.encoded(id))/content")
        let response = try await pipeline.sendRaw(request)
        return response.body
    }

    // MARK: - Pagination

    private func attachFetcher(to page: Page<FileObject>, limit: Int?) -> Page<FileObject> {
        Self.attachFetcher(to: page, pipeline: pipeline, limit: limit)
    }

    private static func attachFetcher(
        to page: Page<FileObject>,
        pipeline: RequestPipeline,
        limit: Int?
    ) -> Page<FileObject> {
        Page(
            data: page.data,
            hasMore: page.hasMore,
            firstId: page.firstId,
            lastId: page.lastId,
            nextPageToken: page.nextPageToken,
            nextPageFetcher: { token in
                let next: Page<FileObject> = try await pipeline.send(
                    listRequest(limit: limit, pageToken: token))
                return attachFetcher(to: next, pipeline: pipeline, limit: limit)
            }
        )
    }
}
