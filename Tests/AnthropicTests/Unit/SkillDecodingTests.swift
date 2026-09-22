import XCTest
@testable import Anthropic
import AnthropicTestSupport

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
///
/// The bodies live in `MockResponses.skill*`, per the repo's fixture convention.
final class SkillDecodingTests: XCTestCase {

    // MARK: - The skill object

    func testDecodesTheDocumentedSkillObject() throws {
        let skill = try JSONCoding.decoder.decode(Skill.self, from: MockResponses.skillObject)

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
        XCTAssertEqual(future.type, .unknown("marketplace"))
        XCTAssertEqual(future.rawType, "marketplace", "the unrecognised value must survive decoding")
    }

    /// `Kind` must round-trip, so a source decoded from a response can be sent straight back as a
    /// filter — including one this SDK does not know.
    func testSourceKindRoundTripsThroughItsRawValue() {
        for kind in SkillSource.Kind.documented {
            XCTAssertEqual(SkillSource.Kind(rawValue: kind.rawValue), kind)
        }
        XCTAssertEqual(SkillSource.Kind.documented.map(\.rawValue),
                       ["custom", "anthropic", "anthropic_example", "plugin"])
        XCTAssertEqual(SkillSource.Kind(rawValue: "marketplace").rawValue, "marketplace")
    }

    /// `name` predates the GA object and is kept as an alias so existing call sites compile.
    @available(*, deprecated, message: "exercises deprecated API on purpose")
    func testNameAliasesDisplayName() throws {
        let skill = try JSONCoding.decoder.decode(Skill.self, from: MockResponses.skillObject)
        XCTAssertEqual(skill.name, "display_name")
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
        XCTAssertNil(skill.updatedAt)
    }

    /// `type` defaults rather than throwing, since it is a constant the API always sends.
    func testTypeDefaultsWhenAbsent() throws {
        let noType = Data("""
        {"id":"skill_01","display_name":"One","created_at":"2025-01-01"}
        """.utf8)
        XCTAssertEqual(try JSONCoding.decoder.decode(Skill.self, from: noType).type, "skill")
    }

    /// Neither `display_name` nor `name`: there is no label to invent, so this must throw.
    func testThrowsWhenNoLabelIsPresent() {
        let unlabelled = Data("""
        {"id":"skill_01","type":"skill","created_at":"2025-01-01"}
        """.utf8)
        XCTAssertThrowsError(try JSONCoding.decoder.decode(Skill.self, from: unlabelled))
    }

    // MARK: - The list envelope

    func testDecodesTheDocumentedListEnvelope() throws {
        let page = try JSONCoding.decoder.decode(Page<Skill>.self, from: MockResponses.skillList)

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.nextPageToken, "next_page")
        XCTAssertTrue(page.hasMore, "a non-null next_page means there is another page")
    }

    /// `next_page: null` is how the documentation says a final page is signalled.
    func testNullNextPageMeansNoMorePages() throws {
        let last = Data("""
        {"data":[],"next_page":null}
        """.utf8)
        let page = try JSONCoding.decoder.decode(Page<Skill>.self, from: last)
        XCTAssertNil(page.nextPageToken)
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
        XCTAssertNil(page.nextPageToken)
    }

    /// An envelope with neither cursor reports no more pages rather than throwing. Documented
    /// here because it is a deliberate choice and it can truncate a list silently — `has_more` was
    /// a required key before the token cursor was added.
    func testEnvelopeWithNeitherCursorReportsNoMorePages() throws {
        let bare = Data("""
        {"data":[]}
        """.utf8)
        let page = try JSONCoding.decoder.decode(Page<Skill>.self, from: bare)
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextPageToken)
        XCTAssertNil(page.lastId)
    }

    /// `hasMore` with no cursor and no fetcher must terminate, not loop or trap.
    func testFetchNextPageReturnsNilWithoutACursor() async throws {
        let fetcherCalled = LockedFlag()
        let page = Page<Skill>(
            data: [], hasMore: true, firstId: nil, lastId: nil, nextPageToken: nil,
            nextPageFetcher: { _ in
                fetcherCalled.set()
                return Page(data: [], hasMore: false, firstId: nil, lastId: nil)
            }
        )
        let next = try await page.fetchNextPage()
        XCTAssertNil(next)
        XCTAssertFalse(fetcherCalled.value, "there was no cursor to fetch with")
    }

    // MARK: - Delete

    func testDecodesTheDocumentedDeleteResponse() throws {
        let deleted = try JSONCoding.decoder.decode(
            SkillDeleteResponse.self, from: MockResponses.skillDeleted)
        XCTAssertEqual(deleted.id, "skill_01JAbcdefghijklmnopqrstuvw")
        XCTAssertEqual(deleted.type, "skill_deleted")
    }

    /// `type` is required: a bare `{"id": …}` must not read as a confirmed deletion.
    func testDeleteResponseRequiresItsType() {
        let bare = Data("""
        {"id":"skill_01"}
        """.utf8)
        XCTAssertThrowsError(try JSONCoding.decoder.decode(SkillDeleteResponse.self, from: bare))
    }
}

/// A `Sendable` boolean a `@Sendable` closure can set.
final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}
