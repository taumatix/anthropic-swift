import Foundation

/// Provides access to the Skills API (beta).
///
/// Access via `AnthropicClient.skills`.
///
/// - Note: This API requires the `skills-2025-10-02` beta header, which is
///   automatically injected by this service.
public final class SkillsService: Sendable {
    private let pipeline: RequestPipeline
    private let betaHeader = "skills-2025-10-02"

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Create

    /// Creates a new skill.
    public func create(_ request: CreateSkillRequest) async throws -> Skill {
        let body = try JSONCoding.encoder.encode(request)
        var httpRequest = HTTPRequest(method: "POST", path: "/v1/skills", body: body)
        httpRequest.headers["anthropic-beta"] = betaHeader
        return try await pipeline.send(httpRequest)
    }

    // MARK: - List

    /// Returns a paginated list of skills.
    public func list(limit: Int? = nil, afterId: String? = nil) async throws -> Page<Skill> {
        var queryItems = PaginationCursor(afterId: afterId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }

        var request = HTTPRequest(method: "GET", path: "/v1/skills", queryItems: queryItems)
        request.headers["anthropic-beta"] = betaHeader
        let page: Page<Skill> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    // MARK: - Get

    /// Returns a specific skill.
    public func get(id: String) async throws -> Skill {
        var request = HTTPRequest(method: "GET", path: "/v1/skills/\(id)")
        request.headers["anthropic-beta"] = betaHeader
        return try await pipeline.send(request)
    }

    // MARK: - Delete

    /// Deletes a skill.
    public func delete(id: String) async throws {
        var request = HTTPRequest(method: "DELETE", path: "/v1/skills/\(id)")
        request.headers["anthropic-beta"] = betaHeader
        _ = try await pipeline.sendRaw(request)
    }

    // MARK: - Pagination

    private func attachFetcher(to page: Page<Skill>) -> Page<Skill> {
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
                    path: "/v1/skills",
                    queryItems: [URLQueryItem(name: "after_id", value: afterId)]
                )
                request.headers["anthropic-beta"] = betaHeader
                let nextPage: Page<Skill> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
