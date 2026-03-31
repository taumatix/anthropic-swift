import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class SSEParserTests: XCTestCase {

    // MARK: - Helpers

    func parseEvents(_ sseString: String) async throws -> [SSEParser.RawSSEEvent] {
        let dataStream = SSEFixtures.lineStream(from: Data(sseString.utf8))
        let parsed = SSEParser.parse(dataStream)
        var events: [SSEParser.RawSSEEvent] = []
        for try await event in parsed {
            events.append(event)
        }
        return events
    }

    // MARK: - Tests

    func testSingleEvent() async throws {
        let sse = """
        event: message_start
        data: {"type":"message_start"}

        """
        let events = try await parseEvents(sse)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "message_start")
        XCTAssertEqual(events[0].data, "{\"type\":\"message_start\"}")
    }

    func testMultipleEvents() async throws {
        let sse = """
        event: ping
        data: {"type":"ping"}

        event: message_stop
        data: {"type":"message_stop"}

        """
        let events = try await parseEvents(sse)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, "ping")
        XCTAssertEqual(events[1].eventType, "message_stop")
    }

    func testCommentLinesIgnored() async throws {
        let sse = """
        : keep-alive

        event: ping
        data: {"type":"ping"}

        """
        let events = try await parseEvents(sse)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "ping")
    }

    func testEventWithoutTypeField() async throws {
        let sse = """
        data: {"type":"ping"}

        """
        let events = try await parseEvents(sse)
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events[0].eventType)
        XCTAssertEqual(events[0].data, "{\"type\":\"ping\"}")
    }

    func testEmptyStreamProducesNoEvents() async throws {
        let events = try await parseEvents("")
        XCTAssertTrue(events.isEmpty)
    }

    func testRealFixtureStreamProducesCorrectEventCount() async throws {
        let dataStream = SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream)
        let parsed = SSEParser.parse(dataStream)
        var events: [SSEParser.RawSSEEvent] = []
        for try await event in parsed {
            events.append(event)
        }
        // basicMessageStream has: message_start, content_block_start, ping,
        // content_block_delta×2, content_block_stop, message_delta, message_stop
        XCTAssertEqual(events.count, 8)
        XCTAssertEqual(events[0].eventType, "message_start")
        XCTAssertEqual(events[2].eventType, "ping")
        XCTAssertEqual(events[7].eventType, "message_stop")
    }
}
