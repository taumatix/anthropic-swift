import XCTest
import Anthropic

/// `AnthropicTestSupport` is a shipped product, so callers write tests against these types: they
/// need to compare, hash and round-trip them like any other value.
final class SkillValueTests: XCTestCase {

    func testSkillFileRoundTripsAndHashes() throws {
        let file = SkillFile(path: "my-skill/SKILL.md", content: Data("---\nname: x\n---\n".utf8), mimeType: "text/markdown")

        let decoded = try JSONDecoder().decode(SkillFile.self, from: JSONEncoder().encode(file))
        XCTAssertEqual(decoded, file)

        let set: Set<SkillFile> = [file, decoded, SkillFile(path: "my-skill/other.md", content: Data())]
        XCTAssertEqual(set.count, 2)
    }

    /// Encoded as the API sends it, so a fixture written from a value decodes as a response would.
    func testSkillSourceEncodesTheAPIsShapeAndKeepsAnUnknownValue() throws {
        for kind in SkillSource.Kind.documented + [.unknown("from_the_future")] {
            let source = SkillSource(type: kind)
            let json = try JSONEncoder().encode(source)
            XCTAssertEqual(String(decoding: json, as: UTF8.self), #"{"type":"\#(kind.rawValue)"}"#)
            XCTAssertEqual(try JSONDecoder().decode(SkillSource.self, from: json), source)
        }
        XCTAssertEqual(Set([SkillSource(type: .custom), SkillSource(type: .custom)]).count, 1)
    }
}
