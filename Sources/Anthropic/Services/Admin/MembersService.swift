import Foundation

/// Provides access to the Organization Members API.
///
/// Access via `AnthropicClient.admin.members`.
public final class MembersService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a paginated list of organization members.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<OrganizationMember> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/members", queryItems: queryItems)
        let page: Page<OrganizationMember> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    /// Updates a member's role.
    public func update(userId: String, request: UpdateMemberRequest) async throws -> OrganizationMember {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "PATCH", path: "/v1/organizations/members/\(userId)", body: body)
        return try await pipeline.send(httpRequest)
    }

    /// Removes a member from the organization.
    public func delete(userId: String) async throws {
        let request = HTTPRequest(method: "DELETE", path: "/v1/organizations/members/\(userId)")
        _ = try await pipeline.sendRaw(request)
    }

    private func attachFetcher(to page: Page<OrganizationMember>) -> Page<OrganizationMember> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/members", queryItems: queryItems)
                let nextPage: Page<OrganizationMember> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
