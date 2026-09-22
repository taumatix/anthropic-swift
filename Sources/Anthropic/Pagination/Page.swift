import Foundation

/// A page of results from a paginated list endpoint.
///
/// `Page` conforms to `AsyncSequence`, allowing transparent multi-page iteration:
/// ```swift
/// for try await model in try await client.models.list() {
///     print(model.id)
/// }
/// ```
/// The iterator automatically fetches subsequent pages as items are consumed.
public struct Page<T: Sendable & Decodable>: Sendable {
    /// The items on this page.
    public let data: [T]
    /// Whether there are more pages after this one.
    public let hasMore: Bool
    /// The ID of the first item on this page.
    public let firstId: String?
    /// The ID of the last item on this page.
    public let lastId: String?
    /// The opaque token for fetching the page after this one, or `nil` if this is the last page.
    ///
    /// Endpoints that paginate by token — the Skills API — return this as `next_page` and expect it
    /// back as the `page` query parameter. Endpoints that paginate by id return `nil` here and
    /// populate ``lastId`` instead.
    ///
    /// Named `…Token` because it is a cursor string, not a `Page`.
    public let nextPageToken: String?

    /// Fetches the next page given the ID of the last item on the current page.
    /// `nil` if there are no more pages.
    private let nextPageFetcher: (@Sendable (String) async throws -> Page<T>)?

    public init(
        data: [T],
        hasMore: Bool,
        firstId: String?,
        lastId: String?,
        nextPageToken: String? = nil,
        nextPageFetcher: (@Sendable (String) async throws -> Page<T>)? = nil
    ) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
        self.nextPageToken = nextPageToken
        self.nextPageFetcher = nextPageFetcher
    }

    /// Fetches the next page, or `nil` if there are no more pages.
    ///
    /// The cursor handed to the fetcher is ``nextPage`` for token-paginated endpoints and
    /// ``lastId`` for id-paginated ones. The service that built the page supplies a fetcher that
    /// knows which of the two it asked for.
    func fetchNextPage() async throws -> Page<T>? {
        guard hasMore, let fetcher = nextPageFetcher else { return nil }
        guard let cursor = nextPageToken ?? lastId else { return nil }
        return try await fetcher(cursor)
    }
}

// MARK: - AsyncSequence

extension Page: AsyncSequence {
    public typealias Element = T

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var currentPage: Page<T>
        private var index: Int

        init(page: Page<T>) {
            self.currentPage = page
            self.index = 0
        }

        public mutating func next() async throws -> T? {
            // Keep fetching until a page has an item. An intermediate page can be empty and still
            // carry a cursor — plausible with a token cursor in a way it was not with an id one —
            // and stopping at the first empty page would silently drop every page after it.
            while true {
                if index < currentPage.data.count {
                    let item = currentPage.data[index]
                    index += 1
                    return item
                }
                guard let nextPage = try await currentPage.fetchNextPage() else { return nil }
                currentPage = nextPage
                index = 0
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(page: self)
    }
}

// MARK: - Decodable

extension Page: Decodable where T: Decodable {
    private enum CodingKeys: String, CodingKey {
        case data, hasMore, firstId, lastId
        case nextPageToken = "nextPage"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode([T].self, forKey: .data)
        self.firstId = try container.decodeIfPresent(String.self, forKey: .firstId)
        self.lastId = try container.decodeIfPresent(String.self, forKey: .lastId)
        self.nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        // Token-paginated envelopes carry no `has_more`: a non-null `next_page` is what says there
        // is another page. Id-paginated envelopes carry `has_more` and no `next_page`.
        if let hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) {
            self.hasMore = hasMore
        } else {
            self.hasMore = self.nextPageToken != nil
        }
        self.nextPageFetcher = nil
    }
}
