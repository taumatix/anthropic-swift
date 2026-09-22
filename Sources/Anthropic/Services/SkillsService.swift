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
            throw Self.invalidFileSet(files, "A skill must be created from at least one file, including a SKILL.md.")
        }
        // Compare the last path component, not a suffix: `hasSuffix("SKILL.md")` also accepts
        // `MYSKILL.md`. Layout beyond this is the API's to adjudicate.
        guard files.contains(where: { ($0.path as NSString).lastPathComponent == "SKILL.md" }) else {
            throw Self.invalidFileSet(files, "A skill's file set must include a file named SKILL.md.")
        }
        guard !files.contains(where: { $0.path.split(separator: "/").contains("..") }) else {
            throw Self.invalidFileSet(files, "A skill file path must not contain a '..' component.")
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
    ///   - limit: Results per page. The API accepts 1...1000 and defaults to 20; a value outside
    ///     that range is passed through and rejected by the server.
    ///   - pageToken: A ``Page/nextPageToken`` from a previous response. `nil` returns the first
    ///     page.
    ///   - source: Return only skills from this source.
    public func list(
        limit: Int? = nil,
        pageToken: String? = nil,
        source: SkillSource.Kind? = nil
    ) async throws -> Page<Skill> {
        let result: Page<Skill> = try await pipeline.send(
            Self.listRequest(limit: limit, pageToken: pageToken, source: source))
        return attachFetcher(to: result, limit: limit, source: source)
    }

    /// Returns a paginated list of skills.
    ///
    /// - Warning: The Skills API paginates by opaque token, not by item id — `after_id` is ignored.
    ///   Use ``list(limit:page:source:)``.
    @available(*, deprecated, message: "The Skills API paginates by token. Use list(limit:pageToken:source:).")
    public func list(limit: Int? = nil, afterId: String?) async throws -> Page<Skill> {
        var queryItems = PaginationCursor(afterId: afterId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        let request = HTTPRequest(method: "GET", path: "/v1/skills", queryItems: queryItems)
        // No fetcher. This overload's response is an id-cursor page, and handing its `lastId` to
        // the token fetcher would re-request the same page under `page=` forever against a server
        // that ignores an unknown parameter. Iteration therefore stops at one page, which is the
        // honest outcome for a cursor the API does not implement.
        return try await pipeline.send(request)
    }

    // MARK: - Get

    /// Returns a specific skill.
    public func get(id: String) async throws -> Skill {
        try await pipeline.send(HTTPRequest(method: "GET", path: Self.skillPath(id)))
    }

    // MARK: - Delete

    /// Deletes a skill.
    @discardableResult
    public func delete(id: String) async throws -> SkillDeleteResponse {
        try await pipeline.send(HTTPRequest(method: "DELETE", path: Self.skillPath(id)))
    }

    // MARK: - Helpers

    /// Builds `/v1/skills/{id}` with the id percent-encoded.
    ///
    /// `HTTPRequest.urlRequest` uses `appendingPathComponent`, which leaves `/` and `..` intact, so
    /// an unencoded id of `../organizations/api_keys` would retarget the request to a different
    /// endpoint carrying the caller's key.
    static func skillPath(_ id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .anthropicPathComponent) ?? id
        return "/v1/skills/\(encoded)"
    }

    private static func listRequest(limit: Int?, pageToken: String?, source: SkillSource.Kind?) -> HTTPRequest {
        var queryItems: [URLQueryItem] = []
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let pageToken = pageToken { queryItems.append(URLQueryItem(name: "page", value: pageToken)) }
        if let source = source {
            // `rawValue` is total, including for `.unknown`, so asking for a source this SDK does
            // not know still sends the filter rather than silently returning everything.
            queryItems.append(URLQueryItem(name: "source", value: source.rawValue))
        }
        return HTTPRequest(method: "GET", path: "/v1/skills", queryItems: queryItems)
    }

    private static func invalidFileSet(_ files: [SkillFile], _ reason: String) -> AnthropicError {
        .encodingError(EncodingError.invalidValue(
            files,
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
            nextPageToken: page.nextPageToken,
            nextPageFetcher: { token in
                let next: Page<Skill> = try await pipeline.send(
                    listRequest(limit: limit, pageToken: token, source: source))
                return attachFetcher(to: next, pipeline: pipeline, limit: limit, source: source)
            }
        )
    }
}

extension CharacterSet {
    /// Characters safe to leave unencoded inside a single path component.
    ///
    /// `urlPathAllowed` permits `/`, which would let an identifier escape its component.
    static let anthropicPathComponent: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/")
        return set
    }()
}
