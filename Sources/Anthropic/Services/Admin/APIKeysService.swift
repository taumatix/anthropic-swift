import Foundation

/// Provides access to the Organization API Keys API.
///
/// Access via `AnthropicClient.admin.apiKeys`.
public final class APIKeysService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a paginated list of API keys in the organization.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<OrganizationAPIKey> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/api_keys", queryItems: queryItems)
        let page: Page<OrganizationAPIKey> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    /// Returns a specific API key.
    public func get(id: String) async throws -> OrganizationAPIKey {
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/api_keys/\(id)")
        return try await pipeline.send(request)
    }

    private func attachFetcher(to page: Page<OrganizationAPIKey>) -> Page<OrganizationAPIKey> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/api_keys", queryItems: queryItems)
                let nextPage: Page<OrganizationAPIKey> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
