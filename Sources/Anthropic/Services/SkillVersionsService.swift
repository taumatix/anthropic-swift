import Foundation

/// Provides access to the versions of a skill.
///
/// Access via `AnthropicClient.skills.versions`.
///
/// ```swift
/// let skill = try await client.skills.get(id: "skill_01...")
/// let running = try await client.skills.versions.get(skillID: skill.id, version: .latest)
/// print(running.description ?? "")
/// ```
///
/// Like ``SkillsService``, this sends no `anthropic-beta` header. Requests that carry
/// `skills-2025-10-02` address versions by Unix epoch timestamp instead of by version ID; this
/// service speaks the GA form.
public final class SkillVersionsService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    /// Returns a page of a skill's versions.
    ///
    /// The returned ``Page`` is an `AsyncSequence` that follows `next_page` as items are consumed.
    ///
    /// - Parameters:
    ///   - skillID: The skill's ID.
    ///   - limit: Results per page. The API accepts 1...1000 and defaults to 20; a value outside
    ///     that range is passed through and rejected by the server.
    ///   - pageToken: A ``Page/nextPageToken`` from a previous response. `nil` returns the first
    ///     page.
    public func list(
        skillID: String,
        limit: Int? = nil,
        pageToken: String? = nil
    ) async throws -> Page<SkillVersion> {
        let page: Page<SkillVersion> = try await pipeline.send(
            Self.listRequest(skillID: skillID, limit: limit, pageToken: pageToken))
        return Self.attachFetcher(to: page, pipeline: pipeline, skillID: skillID, limit: limit)
    }

    /// Returns one version of a skill.
    ///
    /// - Parameters:
    ///   - skillID: The skill's ID.
    ///   - version: A version ID, or ``SkillVersionReference/latest`` for the newest.
    public func get(skillID: String, version: SkillVersionReference) async throws -> SkillVersion {
        try await pipeline.send(HTTPRequest(method: "GET", path: Self.versionPath(skillID, version.pathValue)))
    }

    /// Uploads a new version of a skill.
    ///
    /// - Parameters:
    ///   - skillID: The skill's ID.
    ///   - files: The version's files. All must share one top-level directory, and one must be a
    ///     `SKILL.md` at its root. The `SKILL.md` must resolve to the skill's existing `name`: the
    ///     API refuses an upload that renames the skill.
    /// - Throws: ``AnthropicError/encodingError(_:)`` if `files` is empty or contains no `SKILL.md`,
    ///   without sending a request.
    public func create(skillID: String, files: [SkillFile]) async throws -> SkillVersion {
        let form = try SkillsService.uploadForm(files: files)
        var request = HTTPRequest(method: "POST", path: Self.versionsPath(skillID))
        request.headers["content-type"] = form.contentTypeHeader
        request.body = form.build()
        return try await pipeline.send(request)
    }

    /// Deletes one version of a skill.
    ///
    /// - Parameters:
    ///   - skillID: The skill's ID.
    ///   - version: The version ID, from ``SkillVersion/id``. There is no `latest` form: the
    ///     reference page documents only an ID for delete, and a destructive call should name what it removes.
    @discardableResult
    public func delete(skillID: String, version: String) async throws -> DeletedSkillVersion {
        try await pipeline.send(HTTPRequest(method: "DELETE", path: Self.versionPath(skillID, version)))
    }

    // MARK: - Helpers

    static func versionsPath(_ skillID: String) -> String {
        "\(SkillsService.skillPath(skillID))/versions"
    }

    /// Both segments are percent-encoded: an unencoded `../` in either would retarget the request
    /// to another endpoint carrying the caller's key (see ``SkillsService/skillPath(_:)``).
    static func versionPath(_ skillID: String, _ version: String) -> String {
        let encoded = version.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? version
        return "\(versionsPath(skillID))/\(encoded)"
    }

    private static func listRequest(skillID: String, limit: Int?, pageToken: String?) -> HTTPRequest {
        var queryItems: [URLQueryItem] = []
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let pageToken = pageToken { queryItems.append(URLQueryItem(name: "page", value: pageToken)) }
        return HTTPRequest(method: "GET", path: versionsPath(skillID), queryItems: queryItems)
    }

    /// The fetcher re-attaches itself to each page it fetches; a page decoded from JSON has no
    /// fetcher of its own, so without that iteration would stop at the second page.
    private static func attachFetcher(
        to page: Page<SkillVersion>,
        pipeline: RequestPipeline,
        skillID: String,
        limit: Int?
    ) -> Page<SkillVersion> {
        Page(
            data: page.data,
            hasMore: page.hasMore,
            firstId: page.firstId,
            lastId: page.lastId,
            nextPageToken: page.nextPageToken,
            nextPageFetcher: { token in
                let next: Page<SkillVersion> = try await pipeline.send(
                    listRequest(skillID: skillID, limit: limit, pageToken: token))
                return attachFetcher(to: next, pipeline: pipeline, skillID: skillID, limit: limit)
            }
        )
    }
}
