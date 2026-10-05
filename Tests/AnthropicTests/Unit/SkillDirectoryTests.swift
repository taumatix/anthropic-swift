import XCTest
import Anthropic

/// `SkillFile.directory(at:)` reads a skill's directory into the file set `create` uploads, instead
/// of the caller reading each file, guessing its MIME type and prefixing its path by hand.
final class SkillDirectoryTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Writes `files` (relative path → content) under `root/name` and returns that directory.
    private func skill(named name: String, _ files: [String: String]) throws -> URL {
        let dir = root.appendingPathComponent(name)
        for (path, content) in files {
            let url = dir.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }
        return dir
    }

    func testReadsEveryFileUnderTheSkillsOwnName() throws {
        let dir = try skill(named: "my-skill", [
            "SKILL.md": "---\nname: my-skill\n---\n",
            "scripts/run.py": "print('hi')\n",
            "reference/notes.md": "detail\n",
        ])

        let files = try SkillFile.directory(at: dir)

        XCTAssertEqual(files.map(\.path), [
            "my-skill/SKILL.md",
            "my-skill/reference/notes.md",
            "my-skill/scripts/run.py",
        ], "paths are prefixed with the directory's name and sorted")
        XCTAssertEqual(files[0].content, Data("---\nname: my-skill\n---\n".utf8))
        XCTAssertEqual(files[0].mimeType, "text/markdown")
        XCTAssertFalse(files[2].mimeType.isEmpty)
    }

    /// Hidden files (`.DS_Store`, `.git`) are not part of a skill, and a symbolic link could point
    /// anywhere on the machine, so neither is uploaded.
    func testLeavesOutHiddenFilesAndSymbolicLinks() throws {
        let outside = root.appendingPathComponent("secret.txt")
        try Data("not for upload".utf8).write(to: outside)
        let dir = try skill(named: "linked", [
            "SKILL.md": "---\nname: linked\n---\n",
            ".DS_Store": "junk",
            ".git/config": "[core]",
        ])
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("leak.txt"), withDestinationURL: outside)
        // One pointing inside, too: followed, it would upload SKILL.md a second time.
        try FileManager.default.createSymbolicLink(
            at: dir.appendingPathComponent("alias.md"), withDestinationURL: dir.appendingPathComponent("SKILL.md"))

        let files = try SkillFile.directory(at: dir)

        XCTAssertEqual(files.map(\.path), ["linked/SKILL.md"])
    }

    /// The SKILL.md has to be at the root of the directory, which `create` alone cannot check: it
    /// only sees paths, and accepts one anywhere.
    func testRefusesADirectoryWithoutASkillManifestAtItsRoot() throws {
        let dir = try skill(named: "nested", ["docs/SKILL.md": "---\nname: x\n---\n"])

        XCTAssertThrowsError(try SkillFile.directory(at: dir)) { error in
            guard case AnthropicError.encodingError = error else {
                return XCTFail("expected the invalid-file-set error, got \(error)")
            }
        }
    }

    func testRefusesSomethingThatIsNotADirectory() throws {
        let file = root.appendingPathComponent("SKILL.md")
        try Data("x".utf8).write(to: file)
        XCTAssertThrowsError(try SkillFile.directory(at: file))
    }
}
