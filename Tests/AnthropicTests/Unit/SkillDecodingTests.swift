import XCTest
@testable import Anthropic

/// Decoding assertions for the Skills API object, written against the literal response bodies
/// published by Anthropic rather than against fixtures this SDK invented.
///
/// Sources, retrieved 2026-09-22:
/// - <https://platform.claude.com/docs/en/api/skills/list>
/// - <https://platform.claude.com/docs/en/api/skills/retrieve>
/// - <https://platform.claude.com/docs/en/api/skills/create>
/// - <https://platform.claude.com/docs/en/api/skills/delete>
/// - <https://platform.claude.com/docs/en/api/beta/skills/list> (the `skills-2025-10-02` shape)
///
/// The beta and GA documents describe the *same* object and the *same* envelope. That is the
/// finding these tests exist to pin: there is no shape in which a `name` key is returned.
final class SkillDecodingTests: XCTestCase {

    // MARK: - Fixtures copied verbatim from the documentation

    /// The `Response (200)` example on the Get Skill page.
    static let skillObjectJSON = Data("""
    {
      "id": "skill_01JAbcdefghijklmnopqrstuvw",
      "created_at": "2024-10-30T23:58:27.427722Z",
      "display_name": "display_name",
      "latest_version_id": "latest_version_id",
      "source": {
        "type": "custom"
      },
      "type": "skill",
      "updated_at": "2024-10-30T23:58:27.427722Z"
    }
    """.utf8)

    /// The `Response (200)` example on the List Skills page.
    static let skillListJSON = Data("""
    {
      "data": [
        {
          "id": "skill_01JAbcdefghijklmnopqrstuvw",
          "created_at": "2024-10-30T23:58:27.427722Z",
          "display_name": "display_name",
          "latest_version_id": "latest_version_id",
          "source": {
            "type": "custom"
          },
          "type": "skill",
          "updated_at": "2024-10-30T23:58:27.427722Z"
        }
      ],
      "next_page": "next_page"
    }
    """.utf8)

    /// The `Response (200)` example on the Delete Skill page.
    static let deletedSkillJSON = Data("""
    {
      "id": "skill_01JAbcdefghijklmnopqrstuvw",
      "type": "skill_deleted"
    }
    """.utf8)

    // MARK: - The skill object

    func testDecodesTheDocumentedSkillObject() throws {
        let skill = try JSONCoding.decoder.decode(Skill.self, from: Self.skillObjectJSON)

        XCTAssertEqual(skill.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(skill.type, "skill")
        XCTAssertEqual(skill.displayName, "display_name")
        XCTAssertEqual(skill.latestVersionId, "latest_version_id")
        XCTAssertEqual(skill.createdAt, "2024-10-30T23:58:27.427722Z")
        XCTAssertEqual(skill.updatedAt, "2024-10-30T23:58:27.427722Z")
        XCTAssertEqual(skill.source?.type, .custom)
    }

    /// Every `SkillSource.type` the documentation enumerates, plus one it does not, because a
    /// source Anthropic adds later must not make the whole skill undecodable.
    func testDecodesEverySourceTypeAndToleratesAnUnknownOne() throws {
        let cases: [(String, SkillSource.Kind)] = [
            ("custom", .custom),
            ("anthropic", .anthropic),
            ("anthropic_example", .anthropicExample),
            ("plugin", .plugin),
        ]
        for (raw, expected) in cases {
            let source = try JSONCoding.decoder.decode(
                SkillSource.self, from: Data("{\"type\":\"\(raw)\"}".utf8))
            XCTAssertEqual(source.type, expected, "source type \(raw)")
            XCTAssertEqual(source.rawType, raw)
        }

        let future = try JSONCoding.decoder.decode(
            SkillSource.self, from: Data("{\"type\":\"marketplace\"}".utf8))
        XCTAssertEqual(future.type, .unknown)
        XCTAssertEqual(future.rawType, "marketplace", "the unrecognised value must survive decoding")
    }

    /// `name` predates the GA object and is kept as an alias so existing call sites compile.
    func testNameAliasesDisplayName() throws {
        let skill = try JSONCoding.decoder.decode(Skill.self, from: Self.skillObjectJSON)
        XCTAssertEqual(skill.name, skill.displayName)
    }

    /// A response carrying the pre-GA `name` key and no `display_name` still decodes, so a
    /// deployment pinned to an older shape degrades instead of throwing.
    func testFallsBackToLegacyNameKey() throws {
        let legacy = Data("""
        {"id":"skill_01","type":"skill","name":"My Skill","description":"A skill","created_at":"2025-01-01"}
        """.utf8)
        let skill = try JSONCoding.decoder.decode(Skill.self, from: legacy)
        XCTAssertEqual(skill.displayName, "My Skill")
        XCTAssertEqual(skill.description, "A skill")
        XCTAssertNil(skill.latestVersionId)
        XCTAssertNil(skill.source)
    }

    // MARK: - The list envelope

    func testDecodesTheDocumentedListEnvelope() throws {
        let page = try JSONCoding.decoder.decode(Page<Skill>.self, from: Self.skillListJSON)

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.nextPage, "next_page")
        XCTAssertTrue(page.hasMore, "a non-null next_page means there is another page")
    }

    /// `next_page: null` is how the documentation says a final page is signalled.
    func testNullNextPageMeansNoMorePages() throws {
        let last = Data("""
        {"data":[],"next_page":null}
        """.utf8)
        let page = try JSONCoding.decoder.decode(Page<Skill>.self, from: last)
        XCTAssertNil(page.nextPage)
        XCTAssertFalse(page.hasMore)
    }

    /// The id-cursor envelope that Messages, Models and Files still return must keep working.
    func testIdCursorEnvelopeStillDecodes() throws {
        let idCursor = Data("""
        {"data":[],"has_more":true,"first_id":"a","last_id":"z"}
        """.utf8)
        let page = try JSONCoding.decoder.decode(Page<Skill>.self, from: idCursor)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.firstId, "a")
        XCTAssertEqual(page.lastId, "z")
        XCTAssertNil(page.nextPage)
    }

    // MARK: - Delete

    func testDecodesTheDocumentedDeleteResponse() throws {
        let deleted = try JSONCoding.decoder.decode(DeletedSkill.self, from: Self.deletedSkillJSON)
        XCTAssertEqual(deleted.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(deleted.type, "skill_deleted")
    }
}
