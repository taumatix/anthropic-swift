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
    ///
    /// - Parameters:
    ///   - includeArchived: Include archived workspaces. The API leaves them out unless asked.
    ///   - includeDefault: Include the organization's default workspace. The API leaves it out
    ///     unless asked.
    public func list(
        limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil,
        includeArchived: Bool? = nil, includeDefault: Bool? = nil
    ) async throws -> Page<Workspace> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let includeArchived = includeArchived {
            queryItems.append(URLQueryItem(name: "include_archived", value: "\(includeArchived)"))
        }
        if let includeDefault = includeDefault {
            queryItems.append(URLQueryItem(name: "include_default", value: "\(includeDefault)"))
        }
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/workspaces", queryItems: queryItems)
        let page: Page<Workspace> = try await pipeline.send(request)
        return attachFetcher(to: page, carrying: queryItems.filter { $0.name != "after_id" && $0.name != "before_id" })
    }

    /// Creates a new workspace.
    public func create(_ request: CreateWorkspaceRequest) async throws -> Workspace {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/organizations/workspaces", body: body)
        return try await pipeline.send(httpRequest)
    }

    /// Returns a specific workspace.
    public func get(id: String) async throws -> Workspace {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? id
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/workspaces/\(encoded)")
        return try await pipeline.send(request)
    }

    /// Archives a workspace.
    public func archive(id: String) async throws -> Workspace {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? id
        let request = HTTPRequest(method: "POST", path: "/v1/organizations/workspaces/\(encoded)/archive")
        return try await pipeline.send(request)
    }

    private func attachFetcher(to page: Page<Workspace>, carrying: [URLQueryItem]) -> Page<Workspace> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = carrying + [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/workspaces", queryItems: queryItems)
                let nextPage: Page<Workspace> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
