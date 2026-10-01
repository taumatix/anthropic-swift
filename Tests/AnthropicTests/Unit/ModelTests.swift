import XCTest

@testable import Anthropic

/// Pins each constant to the exact wire ID Anthropic serves. A typo here is a 404 at runtime that
/// no round-trip test would catch, so these assert the literal string rather than re-deriving it.
final class ModelTests: XCTestCase {

    // The four current models as of 2026-10-01, read from the "Claude API ID" row of
    // https://platform.claude.com/docs/en/about-claude/models/overview — not from recall.
    // Everything in testLegacyModelRawValues below is on that page's "Legacy models" line.
    func testCurrentModelRawValues() {
        XCTAssertEqual(Model.claudeFable51.rawValue, "claude-fable-5-1")
        XCTAssertEqual(Model.claudeOpus55.rawValue, "claude-opus-5-5")
        XCTAssertEqual(Model.claudeSonnet55.rawValue, "claude-sonnet-5-5")
        XCTAssertEqual(Model.claudeHaiku45.rawValue, "claude-haiku-4-5")
    }

    // Deprecated 2026-09-30, retiring 2026-11-30, per the "Model status" table of
    // https://platform.claude.com/docs/en/about-claude/model-deprecations, read 2026-10-01.
    // The constants keep their value until then: they still work, and the warning says when they
    // stop. This test is the only place the suite touches them, so it carries their warnings.
    @available(*, deprecated)
    func testDeprecatedSonnet45ConstantsKeepTheirValue() {
        XCTAssertEqual(Model.claudeSonnet45.rawValue, "claude-sonnet-4-5")
        XCTAssertEqual(Model.claude4Sonnet, Model.claudeSonnet45)
    }

    // Invite only, so absent from the overview table. The ID is from
    // https://platform.claude.com/docs/en/models/mythos-5-1/overview, read 2026-09-27.
    func testInviteOnlyModelRawValues() {
        XCTAssertEqual(Model.claudeMythos51.rawValue, "claude-mythos-5-1")
    }

    func testLegacyModelRawValues() {
        XCTAssertEqual(Model.claudeFable5.rawValue, "claude-fable-5")
        XCTAssertEqual(Model.claudeMythos5.rawValue, "claude-mythos-5")
        XCTAssertEqual(Model.claudeOpus5.rawValue, "claude-opus-5")
        XCTAssertEqual(Model.claudeOpus48.rawValue, "claude-opus-4-8")
        XCTAssertEqual(Model.claudeOpus47.rawValue, "claude-opus-4-7")
        XCTAssertEqual(Model.claudeOpus46.rawValue, "claude-opus-4-6")
        XCTAssertEqual(Model.claudeOpus45.rawValue, "claude-opus-4-5")
        XCTAssertEqual(Model.claudeSonnet5.rawValue, "claude-sonnet-5")
        XCTAssertEqual(Model.claudeSonnet46.rawValue, "claude-sonnet-4-6")
    }

    /// The Claude 4 names stay pinned to the 4.5 generation. Repointing them at a newer model
    /// would silently change which model a caller's existing code runs against.
    /// `claude4Sonnet` is checked in testDeprecatedSonnet45ConstantsKeepTheirValue.
    func testClaude4NamesStayPinnedToTheir45Values() {
        XCTAssertEqual(Model.claude4Opus, Model.claudeOpus45)
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
