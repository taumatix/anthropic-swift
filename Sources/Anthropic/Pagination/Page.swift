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

    /// Fetches the next page given the ID of the last item on the current page.
    /// `nil` if there are no more pages.
    private let nextPageFetcher: (@Sendable (String) async throws -> Page<T>)?

    public init(
        data: [T],
        hasMore: Bool,
        firstId: String?,
        lastId: String?,
        nextPageFetcher: (@Sendable (String) async throws -> Page<T>)? = nil
    ) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
        self.nextPageFetcher = nextPageFetcher
    }

    /// Fetches the next page, or `nil` if there are no more pages.
    func fetchNextPage() async throws -> Page<T>? {
        guard hasMore, let lastId = lastId, let fetcher = nextPageFetcher else { return nil }
        return try await fetcher(lastId)
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
            // Return next item from current page
            if index < currentPage.data.count {
                let item = currentPage.data[index]
                index += 1
                return item
            }
            // Try to fetch the next page
            guard let nextPage = try await currentPage.fetchNextPage() else {
                return nil
            }
            currentPage = nextPage
            index = 0
            guard index < currentPage.data.count else { return nil }
            let item = currentPage.data[index]
            index += 1
            return item
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode([T].self, forKey: .data)
        self.hasMore = try container.decode(Bool.self, forKey: .hasMore)
        self.firstId = try container.decodeIfPresent(String.self, forKey: .firstId)
        self.lastId = try container.decodeIfPresent(String.self, forKey: .lastId)
        self.nextPageFetcher = nil
    }
}
