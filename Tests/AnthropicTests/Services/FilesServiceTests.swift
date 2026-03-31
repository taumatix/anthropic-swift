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

    func testUploadSendsBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "files-api-2025-04-14")
            XCTAssertTrue(request.headers["content-type"]?.contains("multipart/form-data") == true)
            return HTTPResponse(statusCode: 200, body: MockResponses.fileObject)
        }
        let file = try await client.files.upload(
            content: Data("test content".utf8),
            filename: "test.txt",
            mimeType: "text/plain"
        )
        XCTAssertEqual(file.id, "file_011CNmFNMT7RRHzqSCnmPwH7")
        XCTAssertEqual(file.filename, "annual_report.pdf")
    }

    func testListFilesSendsBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "files-api-2025-04-14")
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.path, "/v1/files")
            return HTTPResponse(statusCode: 200, body: MockResponses.filesList)
        }
        let page = try await client.files.list()
        XCTAssertEqual(page.data.count, 1)
    }

    func testGetFileSendsBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "files-api-2025-04-14")
            XCTAssertEqual(request.path, "/v1/files/file_011CNmFNMT7RRHzqSCnmPwH7")
            return HTTPResponse(statusCode: 200, body: MockResponses.fileObject)
        }
        let file = try await client.files.get(id: "file_011CNmFNMT7RRHzqSCnmPwH7")
        XCTAssertEqual(file.id, "file_011CNmFNMT7RRHzqSCnmPwH7")
    }

    func testDeleteFile() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            XCTAssertEqual(request.headers["anthropic-beta"], "files-api-2025-04-14")
            return HTTPResponse(statusCode: 200, body: MockResponses.fileDeleted)
        }
        let result = try await client.files.delete(id: "file_011CNmFNMT7RRHzqSCnmPwH7")
        XCTAssertTrue(result.deleted)
    }

    func testDownloadFile() async throws {
        let expectedData = Data("file contents here".utf8)
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/files/file_011CNmFNMT7RRHzqSCnmPwH7/content")
            return HTTPResponse(statusCode: 200, body: expectedData)
        }
        let data = try await client.files.download(id: "file_011CNmFNMT7RRHzqSCnmPwH7")
        XCTAssertEqual(data, expectedData)
    }
}
