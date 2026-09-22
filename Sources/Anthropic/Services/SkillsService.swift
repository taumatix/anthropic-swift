import Foundation

/// One file in a skill's uploaded file set.
///
/// `path` is the file's location relative to the enclosing directory and is sent as the multipart
/// filename. All files must sit under the same top-level directory, which must contain a `SKILL.md`
/// at its root — see <https://platform.claude.com/docs/en/api/skills/create> (retrieved 2026-09-22).
public struct SkillFile: Sendable, Equatable {
    /// Path relative to the enclosing directory, e.g. `"my-skill/SKILL.md"`.
    public let path: String
    /// The file's bytes.
    public let content: Data
    /// MIME type sent for this part.
    public let mimeType: String

    public init(path: String, content: Data, mimeType: String = "application/octet-stream") {
        self.path = path
        self.content = content
        self.mimeType = mimeType
    }
}

/// Provides access to the Skills API.
///
/// Access via `AnthropicClient.skills`.
///
/// ```swift
/// let skill = try await client.skills.create(
///     files: [SkillFile(path: "my-skill/SKILL.md", content: manifest)],
///     displayName: "My Skill"
/// )
/// for try await skill in try await client.skills.list(source: .custom) {
///     print(skill.displayName)
/// }
/// ```
///
/// - Note: This service sends no `anthropic-beta` header. `skills-2025-10-02` is still accepted,
///   but the beta endpoint returns the same object and the same `next_page` envelope as GA, so it
///   changes nothing. To send it anyway, use
///   `ClientOptions.additionalHeaders(["anthropic-beta": "skills-2025-10-02"])`.
public final class SkillsService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Create

    /// Creates a skill from a set of files.
    ///
    /// - Parameters:
    ///   - files: The skill's files. Exactly one must be a `SKILL.md` at the root of the shared
    ///     top-level directory.
    ///   - displayName: Human-readable label. When `nil`, the API derives it from the `SKILL.md`
    ///     frontmatter `name`.
    /// - Throws: ``AnthropicError/encodingError(_:)`` if `files` is empty or contains no `SKILL.md`,
    ///   without sending a request.
    public func create(files: [SkillFile], displayName: String? = nil) async throws -> Skill {
        guard !files.isEmpty else {
            throw Self.invalidFileSet("A skill must be created from at least one file, including a SKILL.md.")
        }
        guard files.contains(where: { $0.path.hasSuffix("SKILL.md") }) else {
            throw Self.invalidFileSet("A skill's file set must include a SKILL.md at the root of its directory.")
        }

        var form = MultipartFormData()
        for file in files {
            form.append(.init(name: "files[]", filename: file.path, contentType: file.mimeType, data: file.content))
        }
        if let displayName = displayName {
            form.append(.init(name: "display_name", filename: nil, contentType: "text/plain", data: Data(displayName.utf8)))
        }

        var request = HTTPRequest(method: "POST", path: "/v1/skills")
        request.headers["content-type"] = form.contentTypeHeader
        request.body = form.build()
        return try await pipeline.send(request)
    }

    /// Creates a new skill.
    ///
    /// - Warning: The API has never accepted a JSON body on `POST /v1/skills`; it takes an uploaded
    ///   file set. This overload sends what it always sent and will fail against the API. Use
    ///   ``create(files:displayName:)``.
    @available(*, deprecated, message: "The API creates skills from uploaded files. Use create(files:displayName:).")
    public func create(_ request: CreateSkillRequest) async throws -> Skill {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/skills", body: body)
        return try await pipeline.send(httpRequest)
    }

    // MARK: - List

    /// Returns a page of skills.
    ///
    /// The returned ``Page`` is an `AsyncSequence` that follows `next_page` as items are consumed.
    ///
    /// - Parameters:
    ///   - limit: Results per page, 1...1000. The API defaults to 20.
    ///   - page: A `next_page` token from a previous response. `nil` returns the first page.
    ///   - source: Return only skills from this source.
    public func list(
        limit: Int? = nil,
        page: String? = nil,
        source: SkillSource.Kind? = nil
    ) async throws -> Page<Skill> {
        let result: Page<Skill> = try await pipeline.send(
            Self.listRequest(limit: limit, page: page, source: source))
        return attachFetcher(to: result, limit: limit, source: source)
    }

    /// Returns a paginated list of skills.
    ///
    /// - Warning: The Skills API paginates by opaque token, not by item id — `after_id` is ignored.
    ///   Use ``list(limit:page:source:)``.
    @available(*, deprecated, message: "The Skills API paginates by token. Use list(limit:page:source:).")
    public func list(limit: Int? = nil, afterId: String?) async throws -> Page<Skill> {
        var queryItems = PaginationCursor(afterId: afterId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        let request = HTTPRequest(method: "GET", path: "/v1/skills", queryItems: queryItems)
        let result: Page<Skill> = try await pipeline.send(request)
        return attachFetcher(to: result, limit: limit, source: nil)
    }

    // MARK: - Get

    /// Returns a specific skill.
    public func get(id: String) async throws -> Skill {
        try await pipeline.send(HTTPRequest(method: "GET", path: "/v1/skills/\(id)"))
    }

    // MARK: - Delete

    /// Deletes a skill.
    @discardableResult
    public func delete(id: String) async throws -> DeletedSkill {
        try await pipeline.send(HTTPRequest(method: "DELETE", path: "/v1/skills/\(id)"))
    }

    // MARK: - Helpers

    private static func listRequest(limit: Int?, page: String?, source: SkillSource.Kind?) -> HTTPRequest {
        var queryItems: [URLQueryItem] = []
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let page = page { queryItems.append(URLQueryItem(name: "page", value: page)) }
        if let source = source, let raw = source.wireValue {
            queryItems.append(URLQueryItem(name: "source", value: raw))
        }
        return HTTPRequest(method: "GET", path: "/v1/skills", queryItems: queryItems)
    }

    private static func invalidFileSet(_ reason: String) -> AnthropicError {
        .encodingError(EncodingError.invalidValue(
            [SkillFile](),
            .init(codingPath: [], debugDescription: reason)
        ))
    }

    /// Attaches a fetcher that carries `limit` and `source` onto the follow-up request, so
    /// iterating a filtered list does not silently widen at the page boundary.
    ///
    /// The fetcher re-attaches itself to each page it fetches. Without that, iteration stops at the
    /// second page: a page decoded from JSON has no fetcher of its own.
    private func attachFetcher(to page: Page<Skill>, limit: Int?, source: SkillSource.Kind?) -> Page<Skill> {
        Self.attachFetcher(to: page, pipeline: pipeline, limit: limit, source: source)
    }

    private static func attachFetcher(
        to page: Page<Skill>,
        pipeline: RequestPipeline,
        limit: Int?,
        source: SkillSource.Kind?
    ) -> Page<Skill> {
        Page(
            data: page.data,
            hasMore: page.hasMore,
            firstId: page.firstId,
            lastId: page.lastId,
            nextPage: page.nextPage,
            nextPageFetcher: { token in
                let next: Page<Skill> = try await pipeline.send(
                    listRequest(limit: limit, page: token, source: source))
                return attachFetcher(to: next, pipeline: pipeline, limit: limit, source: source)
            }
        )
    }
}

extension SkillSource.Kind {
    /// The string the API uses for this source, or `nil` for ``SkillSource/Kind/unknown``, which
    /// has no wire value to send.
    var wireValue: String? {
        switch self {
        case .custom: return "custom"
        case .anthropic: return "anthropic"
        case .anthropicExample: return "anthropic_example"
        case .plugin: return "plugin"
        case .unknown: return nil
        }
    }
}
