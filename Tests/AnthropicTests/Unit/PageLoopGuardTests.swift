import XCTest
@testable import Anthropic

/// A server that hands back the same cursor twice used to make `for try await` over a `Page`
/// fetch the same page for ever: found by a test whose mock replayed one fixture, which hung the
/// suite until it was killed. Each test here runs under a deadline, so a regression fails instead
/// of hanging.
final class PageLoopGuardTests: XCTestCase {

    /// Runs `body`, failing if it has not finished within `seconds`. An expectation rather than a
    /// task group, because a group waits for its children and the bug being guarded against is a
    /// child that never ends: the test must fail, not wait with it.
    private func withDeadline(_ seconds: Double, _ body: @escaping @Sendable () async throws -> Void) async {
        let done = expectation(description: "finished")
        Task {
            do { try await body() } catch { XCTFail("unexpected error: \(error)") }
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: seconds)
    }

    private actor Counter { var n = 0; func bump() -> Int { n += 1; return n } }

    func testARepeatedCursorEndsIterationWithAnError() async throws {
        let fetches = Counter()
        // Every page says the next one is "same", and fetching "same" returns that page again.
        @Sendable func page() -> Page<Int> {
            Page(data: [1], hasMore: true, firstId: nil, lastId: nil, nextPageToken: "same",
                 nextPageFetcher: { _ in _ = await fetches.bump(); return page() })
        }

        await withDeadline(5) {
            var items: [Int] = []
            do {
                for try await item in page() { items.append(item) }
                XCTFail("a repeating cursor ended as if the list were complete")
            } catch AnthropicError.networkError(let error) {
                XCTAssertEqual(error.code, .badServerResponse)
            }
            XCTAssertEqual(items, [1, 1], "the first page and the one fetched with the cursor, then the repeat is refused")
        }
        let n = await fetches.n
        XCTAssertEqual(n, 1, "the repeated cursor was fetched again")
    }

    /// Distinct cursors and empty pages for ever is not detectable as a loop. Cancelling the task
    /// must still end it.
    func testIterationEndsWhenItsTaskIsCancelled() async throws {
        let fetches = Counter()
        @Sendable func page(_ n: Int) -> Page<Int> {
            Page(data: [], hasMore: true, firstId: nil, lastId: nil, nextPageToken: "t\(n)",
                 nextPageFetcher: { _ in _ = await fetches.bump(); return page(n + 1) })
        }

        let task = Task {
            for try await _ in page(0) {}
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        await withDeadline(5) {
            do {
                try await task.value
                XCTFail("an endless listing ended on its own")
            } catch is CancellationError {}
        }
        let n = await fetches.n
        XCTAssertGreaterThan(n, 0)
    }

    /// The guard must not stop a listing that is making progress.
    func testDistinctCursorsStillPageThrough() async throws {
        @Sendable func page(_ n: Int) -> Page<Int> {
            Page(data: [n], hasMore: n < 4, firstId: nil, lastId: nil, nextPageToken: n < 4 ? "t\(n)" : nil,
                 nextPageFetcher: { _ in page(n + 1) })
        }
        var items: [Int] = []
        for try await item in page(0) { items.append(item) }
        XCTAssertEqual(items, [0, 1, 2, 3, 4])
    }
}
