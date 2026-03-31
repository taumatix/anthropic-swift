import Foundation

/// Provides access to the Organization Workspaces API.
///
/// Access via `AnthropicClient.admin.workspaces`.
public final class WorkspacesService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a paginated list of workspaces.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<Workspace> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/workspaces", queryItems: queryItems)
        let page: Page<Workspace> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    /// Creates a new workspace.
    public func create(_ request: CreateWorkspaceRequest) async throws -> Workspace {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/organizations/workspaces", body: body)
        return try await pipeline.send(httpRequest)
    }

    /// Returns a specific workspace.
    public func get(id: String) async throws -> Workspace {
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/workspaces/\(id)")
        return try await pipeline.send(request)
    }

    /// Archives a workspace.
    public func archive(id: String) async throws -> Workspace {
        let request = HTTPRequest(method: "POST", path: "/v1/organizations/workspaces/\(id)/archive")
        return try await pipeline.send(request)
    }

    private func attachFetcher(to page: Page<Workspace>) -> Page<Workspace> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/workspaces", queryItems: queryItems)
                let nextPage: Page<Workspace> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
