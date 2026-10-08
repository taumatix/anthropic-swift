import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class FilesServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testUploadSendsNoBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertNil(request.headers["anthropic-beta"])
            XCTAssertTrue(request.headers["content-type"]?.contains("multipart/form-data") == true)
            return HTTPResponse(statusCode: 200, body: MockResponses.fileObject)
        }
        let file = try await client.files.upload(
            content: Data("test content".utf8),
            filename: "test.txt",
            mimeType: "text/plain"
        )
        XCTAssertEqual(file.id, "file_011CNha8iCJcU1wXNR6q4V8w")
        XCTAssertEqual(file.filename, "document.pdf")
    }

    func testListFilesSendsNoBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertNil(request.headers["anthropic-beta"])
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/v1/files")
            return HTTPResponse(statusCode: 200, body: MockResponses.filesList)
        }
        let page = try await client.files.list()
        XCTAssertEqual(page.data.count, 1)
    }

    func testGetFileSendsNoBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertNil(request.headers["anthropic-beta"])
            XCTAssertEqual(request.path, "/v1/files/file_011CNha8iCJcU1wXNR6q4V8w")
            return HTTPResponse(statusCode: 200, body: MockResponses.fileObject)
        }
        let file = try await client.files.get(id: "file_011CNha8iCJcU1wXNR6q4V8w")
        XCTAssertEqual(file.id, "file_011CNha8iCJcU1wXNR6q4V8w")
    }

    func testDeleteFile() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            XCTAssertNil(request.headers["anthropic-beta"])
            return HTTPResponse(statusCode: 200, body: MockResponses.fileDeleted)
        }
        let result = try await client.files.delete(id: "file_011CNha8iCJcU1wXNR6q4V8w")
        XCTAssertTrue(result.deleted)
    }

    func testDownloadFile() async throws {
        let expectedData = Data("file contents here".utf8)
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/files/file_011CNha8iCJcU1wXNR6q4V8w/content")
            return HTTPResponse(statusCode: 200, body: expectedData)
        }
        let data = try await client.files.download(id: "file_011CNha8iCJcU1wXNR6q4V8w")
        XCTAssertEqual(data, expectedData)
    }

    // MARK: - Documented wire shapes (retrieved 2026-10-09)

    func testDocumentedFileMetadataDecodes() throws {
        let file = try JSONCoding.decoder.decode(FileObject.self, from: MockResponses.fileObject)
        XCTAssertEqual(file.id, "file_011CNha8iCJcU1wXNR6q4V8w")
        XCTAssertEqual(file.type, "file")
        XCTAssertEqual(file.mimeType, "application/pdf")
        XCTAssertEqual(file.size, 102400)
        XCTAssertEqual(file.sizeBytes, 102400)
        XCTAssertFalse(file.downloadable)
        XCTAssertEqual(file.createdAtString, "2025-04-15T18:37:24.100435Z")
        XCTAssertEqual(file.createdAt, 1_744_742_244)
        XCTAssertEqual(file.expiresAt, "2025-05-15T18:37:24.100435Z")
    }

    func testFileWithoutOptionalFieldsOrWithNullExpiryDecodes() throws {
        let body = Data("""
        {"id":"file_1","created_at":"2025-04-15T18:37:24Z","filename":"a.txt","mime_type":"text/plain","size_bytes":3,"type":"file","expires_at":null}
        """.utf8)
        let file = try JSONCoding.decoder.decode(FileObject.self, from: body)
        XCTAssertNil(file.expiresAt)
        XCTAssertFalse(file.downloadable)
        XCTAssertEqual(file.createdAt, 1_744_742_244)
    }

    func testPreGAShapeStillDecodes() throws {
        let body = Data("""
        {"id":"file_1","type":"file","filename":"a.pdf","size":4096,"created_at":1714041600,"purpose":"assistants"}
        """.utf8)
        let file = try JSONCoding.decoder.decode(FileObject.self, from: body)
        XCTAssertEqual(file.size, 4096)
        XCTAssertEqual(file.createdAt, 1_714_041_600)
        XCTAssertNil(file.createdAtString)
        XCTAssertNil(file.mimeType)
    }

    func testDocumentedDeleteBodyDecodesAsDeleted() throws {
        let result = try JSONCoding.decoder.decode(FileDeleteResponse.self, from: MockResponses.fileDeleted)
        XCTAssertEqual(result.type, "file_deleted")
        XCTAssertTrue(result.deleted)
    }

    func testDeleteBodyOfAnotherTypeIsNotReportedDeleted() throws {
        let body = Data(#"{"id":"file_1","type":"something_else"}"#.utf8)
        XCTAssertFalse(try JSONCoding.decoder.decode(FileDeleteResponse.self, from: body).deleted)
    }

    func testListEnvelopeCarriesNextPageToken() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.filesList) }
        let page = try await client.files.list(limit: 1)
        XCTAssertEqual(page.nextPageToken, "page_MjAyNS0wNS0xNFQwMDowMDowMFo=")
        XCTAssertTrue(page.hasMore)
    }

    func testListFollowsNextPageAcrossPages() async throws {
        mock.handler = { request in
            let token = request.queryItems.first { $0.name == "page" }?.value
            XCTAssertEqual(request.queryItems.first { $0.name == "limit" }?.value, "1")
            if token == nil { return HTTPResponse(statusCode: 200, body: MockResponses.filesList) }
            XCTAssertEqual(token, "page_MjAyNS0wNS0xNFQwMDowMDowMFo=")
            return HTTPResponse(statusCode: 200, body: Data(#"{"data":[],"next_page":null}"#.utf8))
        }
        var count = 0
        for try await _ in try await client.files.list(limit: 1) { count += 1 }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(mock.recordedRequests.count, 2)
    }

    func testUploadSendsExpiresInSecondsAsAFormField() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.fileObject) }
        _ = try await client.files.upload(
            content: Data("x".utf8), filename: "a.txt", mimeType: "text/plain", expiresInSeconds: 3600)
        let body = String(decoding: mock.recordedRequests[0].body ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains(#"name="expires_in_seconds""#))
        XCTAssertTrue(body.contains("\r\n\r\n3600\r\n"))
    }

    func testUploadWithoutExpiryOmitsTheField() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.fileObject) }
        _ = try await client.files.upload(content: Data("x".utf8), filename: "a.txt", mimeType: "text/plain")
        let body = String(decoding: mock.recordedRequests[0].body ?? Data(), as: UTF8.self)
        XCTAssertFalse(body.contains("expires_in_seconds"))
    }

    func testFileIDIsPercentEncodedInThePath() async throws {
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.fileObject) }
        _ = try await client.files.get(id: "../x")
        XCTAssertEqual(mock.recordedRequests[0].path, "/v1/files/..%2Fx")
    }
}
