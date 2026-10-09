import Foundation

/// Provides access to the Organization Invites API.
///
/// Access via `AnthropicClient.admin.invites`.
public final class InvitesService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a paginated list of invites.
    ///
    /// - Parameters:
    ///   - email: Only invites sent to this address.
    ///   - roles: Only invites for one of these roles (repeated `roles` items).
    ///   - statuses: Only invites in one of these states (`pending`, `accepted`, `expired`); repeated `statuses` items.
    public func list(
        limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil,
        email: String? = nil, roles: [String]? = nil, statuses: [String]? = nil
    ) async throws -> Page<OrganizationInvite> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let email = email { queryItems.append(URLQueryItem(name: "email", value: email)) }
        for role in roles ?? [] { queryItems.append(URLQueryItem(name: "roles", value: role)) }
        for status in statuses ?? [] { queryItems.append(URLQueryItem(name: "statuses", value: status)) }
        let carrying = queryItems
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/invites", queryItems: queryItems)
        let page: Page<OrganizationInvite> = try await pipeline.send(request)
        return attachFetcher(to: page, carrying: carrying)
    }

    /// Creates a new invitation.
    public func create(_ request: CreateInviteRequest) async throws -> OrganizationInvite {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/organizations/invites", body: body)
        return try await pipeline.send(httpRequest)
    }

    /// Gets a specific invite.
    public func get(id: String) async throws -> OrganizationInvite {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? id
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/invites/\(encoded)")
        return try await pipeline.send(request)
    }

    /// Deletes (cancels) an invite.
    public func delete(id: String) async throws -> InviteDeleteResponse {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? id
        let request = HTTPRequest(method: "DELETE", path: "/v1/organizations/invites/\(encoded)")
        return try await pipeline.send(request)
    }

    private func attachFetcher(to page: Page<OrganizationInvite>, carrying: [URLQueryItem]) -> Page<OrganizationInvite> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = carrying.filter { $0.name != "after_id" && $0.name != "before_id" } + [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/invites", queryItems: queryItems)
                let nextPage: Page<OrganizationInvite> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
