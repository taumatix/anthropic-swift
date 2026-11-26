import XCTest
import Anthropic

/// Files API against `api.anthropic.com`. Creates and deletes one small file; bills nothing.
///
/// Confirms what ROADMAP.md lists as unconfirmed: that the GA bodies are served with no beta
/// header, and that `ids[]` is an accepted spelling for `list(ids:)`.
final class LiveFilesTests: IntegrationTestCase {

    func testUploadGetListDownloadDeleteRoundTrip() async throws {
        let body = Data("anthropic-swift live test \(UUID().uuidString)".utf8)
        let uploaded = try await client.files.upload(
            content: body, filename: "live-test.txt", mimeType: "text/plain", expiresInSeconds: 3600)
        // Always remove it, even if an assertion below fails.
        addTeardownBlock { [client] in _ = try? await client!.files.delete(id: uploaded.id) }

        XCTAssertEqual(uploaded.type, "file")
        XCTAssertEqual(uploaded.filename, "live-test.txt")
        XCTAssertEqual(uploaded.size, body.count)
        XCTAssertNotNil(uploaded.expiresAt, "expires_in_seconds was sent but no expires_at came back")

        let fetched = try await client.files.get(id: uploaded.id)
        XCTAssertEqual(fetched.id, uploaded.id)

        let byIds = try await client.files.list(ids: [uploaded.id])
        XCTAssertEqual(byIds.data.map(\.id), [uploaded.id], "list(ids:) did not filter to the file")

        do {
            let downloaded = try await client.files.download(id: uploaded.id)
            XCTAssertEqual(downloaded, body)
        } catch let error as AnthropicError {
            // Uploaded files are documented as not downloadable; only files a tool produced are.
            XCTAssertFalse(fetched.downloadable, "downloadable file refused its download: \(error)")
        }

        let deleted = try await client.files.delete(id: uploaded.id)
        XCTAssertTrue(deleted.deleted)
        XCTAssertEqual(deleted.id, uploaded.id)
    }
}
