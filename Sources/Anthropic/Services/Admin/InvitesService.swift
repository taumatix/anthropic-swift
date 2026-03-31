import Foundation

/// Provides access to the Organization Invites API.
///
/// Access via `AnthropicClient.admin.invites`.
public final class InvitesService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a paginated list of pending invites.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<OrganizationInvite> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/invites", queryItems: queryItems)
        let page: Page<OrganizationInvite> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    /// Creates a new invitation.
    public func create(_ request: CreateInviteRequest) async throws -> OrganizationInvite {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/organizations/invites", body: body)
        return try await pipeline.send(httpRequest)
    }

    /// Gets a specific invite.
    public func get(id: String) async throws -> OrganizationInvite {
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/invites/\(id)")
        return try await pipeline.send(request)
    }

    /// Deletes (cancels) an invite.
    public func delete(id: String) async throws -> InviteDeleteResponse {
        let request = HTTPRequest(method: "DELETE", path: "/v1/organizations/invites/\(id)")
        return try await pipeline.send(request)
    }

    private func attachFetcher(to page: Page<OrganizationInvite>) -> Page<OrganizationInvite> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/invites", queryItems: queryItems)
                let nextPage: Page<OrganizationInvite> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
