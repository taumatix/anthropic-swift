import XCTest
@testable import Anthropic
import AnthropicTestSupport

/// Decoding and addressing for skill versions, asserted against the literal `Response (200)` bodies
/// at <https://platform.claude.com/docs/en/api/skills/versions/retrieve> and `.../versions/list`
/// (retrieved 2026-10-09).
final class SkillVersionTests: XCTestCase {

    func testDecodesTheDocumentedVersionObject() throws {
        let version = try JSONCoding.decoder.decode(SkillVersion.self, from: MockResponses.skillVersionObject)

        XCTAssertEqual(version.id, "id")
        XCTAssertEqual(version.type, "skill_version")
        XCTAssertEqual(version.skillId, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(version.name, "name")
        XCTAssertEqual(version.description, "description")
        XCTAssertEqual(version.createdAt, "2024-10-30T23:58:27.427722Z")
    }

    func testDecodesTheDocumentedListEnvelope() throws {
        let page = try JSONCoding.decoder.decode(Page<SkillVersion>.self, from: MockResponses.skillVersionList)

        XCTAssertEqual(page.data.map(\.id), ["id"])
        XCTAssertEqual(page.nextPageToken, "next_page")
    }

    /// A field Anthropic adds later, and one it omits, must not make the whole version undecodable.
    func testToleratesAnUnknownFieldAndAnOmittedOptionalOne() throws {
        let body = Data("""
        {"id":"v1","skill_id":"skill_01","created_at":"2025-01-01T00:00:00Z","future_field":{"a":1}}
        """.utf8)
        let version = try JSONCoding.decoder.decode(SkillVersion.self, from: body)

        XCTAssertEqual(version.type, "skill_version")
        XCTAssertNil(version.name)
        XCTAssertNil(version.description)
    }

    func testAVersionWithoutItsSkillIDDoesNotDecode() {
        let body = Data(#"{"id":"v1","created_at":"2025-01-01T00:00:00Z"}"#.utf8)
        XCTAssertThrowsError(try JSONCoding.decoder.decode(SkillVersion.self, from: body))
    }

    func testLatestIsExpressibleAsTheAPIsLiteralAndEveryOtherStringIsAnID() {
        let literal: SkillVersionReference = "latest"
        XCTAssertEqual(literal, .latest)
        XCTAssertEqual(literal.pathValue, "latest")

        let pinned: SkillVersionReference = "1759178010641129"
        XCTAssertEqual(pinned, .id("1759178010641129"))
        XCTAssertEqual(SkillVersionReference.id("latest").pathValue, "latest",
                       "an explicit .id is never reinterpreted")
    }
}
