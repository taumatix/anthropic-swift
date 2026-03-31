import Foundation

/// Provides access to the Models API.
///
/// Access via `AnthropicClient.models`.
public final class ModelsService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - List Models

    /// Returns a paginated list of available models.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of results per page (1–1000, default 20).
    ///   - afterId: Return results after this ID (for cursor-based pagination).
    ///   - beforeId: Return results before this ID.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<ModelInfo> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }

        let request = HTTPRequest(method: "GET", path: "/v1/models", queryItems: queryItems)
        var page: Page<ModelInfo> = try await pipeline.send(request)
        page = attachFetcher(to: page)
        return page
    }

    /// Returns information about a specific model.
    ///
    /// - Parameter id: The model identifier (e.g., `"claude-opus-4-5"`).
    public func get(id: String) async throws -> ModelInfo {
        let request = HTTPRequest(method: "GET", path: "/v1/models/\(id)")
        return try await pipeline.send(request)
    }

    // MARK: - Pagination

    private func attachFetcher(to page: Page<ModelInfo>) -> Page<ModelInfo> {
        let pipeline = self.pipeline
        return Page(
            data: page.data,
            hasMore: page.hasMore,
            firstId: page.firstId,
            lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/models", queryItems: queryItems)
                let nextPage: Page<ModelInfo> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
