import XCTest
import Anthropic

/// Skills API tests against `api.anthropic.com`.
///
/// This is the only test in the suite that can tell you what Anthropic currently returns. Every
/// other Skills test replays a body copied from the documentation, which proves this SDK agrees
/// with what Anthropic *published* — not with what it *serves*. That gap is exactly how the object
/// this SDK decoded stayed wrong from its first release with a green suite throughout.
///
/// Skipped unless `ANTHROPIC_API_KEY` is set. The round trip that creates and deletes a skill also
/// needs `ANTHROPIC_SKILLS_WRITE_TESTS=1`, because it mutates the caller's workspace.
final class LiveSkillsTests: IntegrationTestCase {

    /// Reads the GA list endpoint and asserts the fields this SDK now depends on are really there.
    func testListReturnsTheDocumentedShape() async throws {
        let page = try await client.skills.list(limit: 1)

        // An empty workspace is a legitimate result; it just cannot confirm the object shape.
        guard let skill = page.data.first else {
            throw XCTSkip("No skills in this workspace, so the object shape cannot be checked.")
        }

        XCTAssertEqual(skill.type, "skill")
        XCTAssertFalse(skill.id.isEmpty)
        XCTAssertFalse(skill.displayName.isEmpty, "display_name is documented as always set")
        XCTAssertNotNil(skill.latestVersionId, "latest_version_id is documented as always set")
        XCTAssertNotNil(skill.updatedAt)
        let source = try XCTUnwrap(skill.source)
        XCTAssertTrue(SkillSource.Kind.documented.contains(source.type),
                      "unrecognised source '\(source.rawType)' — the API has added a value")
    }

    /// Whether `skills-2025-10-02` is still honoured, and whether it changes the response.
    ///
    /// The documentation says it should not: the beta and GA reference pages describe the same
    /// object. If this fails, that assumption has expired and `ROADMAP.md` needs an entry.
    func testBetaHeaderReturnsTheSameShapeAsGA() async throws {
        let apiKey = try XCTUnwrap(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"])
        let betaClient = AnthropicClient(
            apiKey: apiKey,
            options: ClientOptions(apiKey: apiKey)
                .timeout(60)
                .maxRetries(1)
                .additionalHeaders(["anthropic-beta": "skills-2025-10-02"])
        )

        let beta = try await betaClient.skills.list(limit: 1)
        let ga = try await client.skills.list(limit: 1)

        XCTAssertEqual(beta.data.map(\.id), ga.data.map(\.id))
        XCTAssertEqual(beta.data.map(\.displayName), ga.data.map(\.displayName))
    }

    /// Create, read and delete a skill over the real API.
    func testCreateGetDeleteRoundTrip() async throws {
        guard ProcessInfo.processInfo.environment["ANTHROPIC_SKILLS_WRITE_TESTS"] == "1" else {
            throw XCTSkip("Set ANTHROPIC_SKILLS_WRITE_TESTS=1 to run the round trip; it creates and deletes a skill.")
        }

        let name = "swift-sdk-e2e-\(UUID().uuidString.prefix(8))"
        let manifest = """
        ---
        name: \(name)
        description: Temporary skill created by the anthropic-swift end-to-end test suite.
        ---

        This skill exists only for a test and is deleted by the same test.
        """

        let created = try await client.skills.create(
            files: [SkillFile(path: "\(name)/SKILL.md",
                              content: Data(manifest.utf8),
                              mimeType: "text/markdown")],
            displayName: name
        )
        XCTAssertEqual(created.displayName, name)
        XCTAssertEqual(created.source?.type, .custom)
        XCTAssertNotNil(created.latestVersionId)

        // Delete in a way that survives a failure above it — reporting an orphan is not cleaning
        // one up, and a failed CI run would leave a skill in the workspace every time.
        var deleted = false
        do {
            let fetched = try await client.skills.get(id: created.id)
            XCTAssertEqual(fetched.id, created.id)
            XCTAssertEqual(fetched.displayName, name)

            let response = try await client.skills.delete(id: created.id)
            XCTAssertEqual(response.id, created.id)
            XCTAssertEqual(response.type, "skill_deleted")
            deleted = true
        } catch {
            if !deleted {
                _ = try? await client.skills.delete(id: created.id)
            }
            throw error
        }
    }
}
