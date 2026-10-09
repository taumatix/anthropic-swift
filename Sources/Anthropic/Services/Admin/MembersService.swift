import Foundation

/// Provides access to the Organization Members API.
///
/// Access via `AnthropicClient.admin.members`.
public final class MembersService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a paginated list of members.
    ///
    /// - Parameters:
    ///   - email: Only the member with this email.
    ///   - roles: Only members whose role is one of these (sent as repeated `roles` items).
    public func list(
        limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil,
        email: String? = nil, roles: [String]? = nil
    ) async throws -> Page<OrganizationMember> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let email = email { queryItems.append(URLQueryItem(name: "email", value: email)) }
        for role in roles ?? [] { queryItems.append(URLQueryItem(name: "roles", value: role)) }
        let carrying = queryItems
        let request = HTTPRequest(method: "GET", path: "/v1/organizations/users", queryItems: queryItems)
        let page: Page<OrganizationMember> = try await pipeline.send(request)
        return attachFetcher(to: page, carrying: carrying)
    }

    /// Updates a member's role.
    public func update(userId: String, request: UpdateMemberRequest) async throws -> OrganizationMember {
        let body = try JSONCoding.encoder.encode(request)
        let encoded = userId.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? userId
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/organizations/users/\(encoded)", body: body)
        return try await pipeline.send(httpRequest)
    }

    /// Removes a member from the organization.
    public func delete(userId: String) async throws {
        let encoded = userId.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? userId
        let request = HTTPRequest(method: "DELETE", path: "/v1/organizations/users/\(encoded)")
        _ = try await pipeline.sendRaw(request)
    }

    private func attachFetcher(to page: Page<OrganizationMember>, carrying: [URLQueryItem]) -> Page<OrganizationMember> {
        let pipeline = self.pipeline
        return Page(
            data: page.data, hasMore: page.hasMore, firstId: page.firstId, lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = carrying.filter { $0.name != "after_id" && $0.name != "before_id" } + [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/organizations/users", queryItems: queryItems)
                let nextPage: Page<OrganizationMember> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
