#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// End-to-end tests for the Files API over a real TCP socket, replaying the response bodies
/// Anthropic publishes (retrieved 2026-10-09). `MockHTTPClient`-based tests cannot disagree with
/// the transport; these can. Not covered: that Anthropic still returns these bodies.
final class FilesEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    private func startClient(
        responder: @escaping LoopbackHTTPServer.Responder
    ) async throws -> AnthropicClient {
        let server = try LoopbackHTTPServer(responder: responder)
        self.server = server
        let baseURL = try await server.start()
        return AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0)
        )
    }

    func testUploadGetListAndDeleteDecodeTheDocumentedBodiesOverARealSocket() async throws {
        let second = Data("""
        {"data":[{"id":"file_2","created_at":"2025-04-16T00:00:00Z","filename":"b.txt",
          "mime_type":"text/plain","size_bytes":1,"type":"file"}],"next_page":null}
        """.utf8)
        let client = try await startClient { request in
            switch (request.method, request.path) {
            case ("POST", "/v1/files"): return .json(200, MockResponses.fileObject)
            case ("DELETE", _): return .json(200, MockResponses.fileDeleted)
            case ("GET", "/v1/files"):
                return request.query["page"] != nil ? .json(200, second) : .json(200, MockResponses.filesList)
            default: return .json(200, MockResponses.fileObject)
            }
        }

        let uploaded = try await client.files.upload(
            content: Data("hello".utf8), filename: "document.pdf", mimeType: "application/pdf",
            expiresInSeconds: 7200)
        XCTAssertEqual(uploaded.mimeType, "application/pdf")
        XCTAssertEqual(uploaded.expiresAt, "2025-05-15T18:37:24.100435Z")

        let fetched = try await client.files.get(id: uploaded.id)
        XCTAssertEqual(fetched, uploaded)

        var names: [String] = []
        for try await file in try await client.files.list(limit: 1) { names.append(file.filename) }
        XCTAssertEqual(names, ["document.pdf", "b.txt"])

        let deleted = try await client.files.delete(id: uploaded.id)
        XCTAssertTrue(deleted.deleted)

        let requests = server.receivedRequests
        XCTAssertEqual(requests.map(\.method), ["POST", "GET", "GET", "GET", "DELETE"])
        XCTAssertTrue(requests[0].headers["content-type"]?.hasPrefix("multipart/form-data") == true)
        XCTAssertTrue(String(decoding: requests[0].body, as: UTF8.self).contains("\r\n\r\n7200\r\n"))
        XCTAssertTrue(requests.allSatisfy { $0.headers["anthropic-beta"] == nil })
        XCTAssertEqual(requests[2].query["limit"], "1")
        XCTAssertNil(requests[2].query["page"])
        XCTAssertEqual(requests[3].query["page"], "page_MjAyNS0wNS0xNFQwMDowMDowMFo=")
        XCTAssertEqual(requests[3].query["limit"], "1")
    }
}
#endif
