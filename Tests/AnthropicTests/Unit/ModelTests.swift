import XCTest

@testable import Anthropic

/// Pins each constant to the exact wire ID Anthropic serves. A typo here is a 404 at runtime that
/// no round-trip test would catch, so these assert the literal string rather than re-deriving it.
final class ModelTests: XCTestCase {

    func testCurrentModelRawValues() {
        XCTAssertEqual(Model.claudeFable5.rawValue, "claude-fable-5")
        XCTAssertEqual(Model.claudeMythos5.rawValue, "claude-mythos-5")
        XCTAssertEqual(Model.claudeOpus5.rawValue, "claude-opus-5")
        XCTAssertEqual(Model.claudeOpus48.rawValue, "claude-opus-4-8")
        XCTAssertEqual(Model.claudeOpus47.rawValue, "claude-opus-4-7")
        XCTAssertEqual(Model.claudeOpus46.rawValue, "claude-opus-4-6")
        XCTAssertEqual(Model.claudeOpus45.rawValue, "claude-opus-4-5")
        XCTAssertEqual(Model.claudeSonnet5.rawValue, "claude-sonnet-5")
        XCTAssertEqual(Model.claudeSonnet46.rawValue, "claude-sonnet-4-6")
        XCTAssertEqual(Model.claudeSonnet45.rawValue, "claude-sonnet-4-5")
        XCTAssertEqual(Model.claudeHaiku45.rawValue, "claude-haiku-4-5")
    }

    /// The Claude 4 names stay pinned to the 4.5 generation. Repointing them at a newer model
    /// would silently change which model a caller's existing code runs against.
    func testClaude4NamesStayPinnedToTheir45Values() {
        XCTAssertEqual(Model.claude4Opus, Model.claudeOpus45)
        XCTAssertEqual(Model.claude4Sonnet, Model.claudeSonnet45)
        XCTAssertEqual(Model.claude4Haiku.rawValue, "claude-haiku-4-5-20251001")
    }

    func testCustomModelIDsArePreserved() {
        // The catalogue is a convenience; an ID the SDK has never heard of must pass through.
        XCTAssertEqual(Model(rawValue: "claude-some-future-model").rawValue, "claude-some-future-model")

        let literal: Model = "claude-another-future-model"
        XCTAssertEqual(literal.rawValue, "claude-another-future-model")
    }

    func testModelEncodesAsBareString() throws {
        let data = try JSONCoding.encoder.encode(Model.claudeSonnet5)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"claude-sonnet-5\"")
    }

    func testModelDecodesFromBareString() throws {
        let decoded = try JSONCoding.decoder.decode(Model.self, from: Data("\"claude-opus-5\"".utf8))
        XCTAssertEqual(decoded, .claudeOpus5)
    }
}
