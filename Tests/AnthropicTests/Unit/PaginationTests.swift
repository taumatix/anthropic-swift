import XCTest
@testable import Anthropic

final class PaginationTests: XCTestCase {

    // MARK: - Single Page

    func testSinglePageIteratesAllItems() async throws {
        let page = Page<ModelInfo>(
            data: [
                ModelInfo(type: "model", id: "a", displayName: "A", createdAt: "2025-01-01"),
                ModelInfo(type: "model", id: "b", displayName: "B", createdAt: "2025-01-01"),
            ],
            hasMore: false,
            firstId: "a",
            lastId: "b"
        )

        var collected: [ModelInfo] = []
        for try await item in page {
            collected.append(item)
        }
        XCTAssertEqual(collected.map(\.id), ["a", "b"])
    }

    func testSinglePageHasNoMoreFetchesNextPage() async throws {
        nonisolated(unsafe) var fetchCount = 0
        let page = Page<ModelInfo>(
            data: [ModelInfo(type: "model", id: "a", displayName: "A", createdAt: "2025-01-01")],
            hasMore: false,
            firstId: "a",
            lastId: "a",
            nextPageFetcher: { _ in
                fetchCount += 1
                return Page(data: [], hasMore: false, firstId: nil, lastId: nil)
            }
        )

        var items: [ModelInfo] = []
        for try await item in page { items.append(item) }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(fetchCount, 0, "Should not fetch next page when hasMore=false")
    }

    // MARK: - Multi-Page

    func testMultiPageIteratorFetchesNextPage() async throws {
        nonisolated(unsafe) var fetchedAfterId: String? = nil
        let page1 = Page<ModelInfo>(
            data: [ModelInfo(type: "model", id: "a", displayName: "A", createdAt: "2025-01-01")],
            hasMore: true,
            firstId: "a",
            lastId: "a",
            nextPageFetcher: { afterId in
                fetchedAfterId = afterId
                return Page(
                    data: [ModelInfo(type: "model", id: "b", displayName: "B", createdAt: "2025-01-01")],
                    hasMore: false,
                    firstId: "b",
                    lastId: "b"
                )
            }
        )

        var items: [ModelInfo] = []
        for try await item in page1 { items.append(item) }
        XCTAssertEqual(items.map(\.id), ["a", "b"])
        XCTAssertEqual(fetchedAfterId, "a")
    }

    // MARK: - Decodable

    func testPageDecodesFromJSON() throws {
        let json = """
        {
          "data": [{"type":"model","id":"m1","display_name":"M1","created_at":"2025-01-01"}],
          "has_more": true,
          "first_id": "m1",
          "last_id": "m1"
        }
        """
        let page = try JSONCoding.decoder.decode(Page<ModelInfo>.self, from: Data(json.utf8))
        XCTAssertEqual(page.data.count, 1)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.firstId, "m1")
    }
}
