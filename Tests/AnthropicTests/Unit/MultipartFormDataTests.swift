import XCTest
@testable import Anthropic

final class MultipartFormDataTests: XCTestCase {

    func testBuildContainsBoundary() {
        var form = MultipartFormData(boundary: "TEST_BOUNDARY")
        form.append(.init(name: "file", filename: "test.txt", contentType: "text/plain", data: Data("hello".utf8)))
        let body = form.build()
        let bodyStr = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyStr.contains("--TEST_BOUNDARY"))
        XCTAssertTrue(bodyStr.contains("--TEST_BOUNDARY--"))
    }

    func testBuildContainsFilename() {
        var form = MultipartFormData(boundary: "B")
        form.append(.init(name: "file", filename: "report.pdf", contentType: "application/pdf", data: Data()))
        let body = form.build()
        let bodyStr = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyStr.contains("filename=\"report.pdf\""))
    }

    func testBuildContainsContentType() {
        var form = MultipartFormData(boundary: "B")
        form.append(.init(name: "file", filename: nil, contentType: "text/plain", data: Data()))
        let body = form.build()
        let bodyStr = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyStr.contains("Content-Type: text/plain"))
    }

    func testBuildContainsFileData() {
        let content = "Hello, World!"
        var form = MultipartFormData(boundary: "B")
        form.append(.init(name: "file", filename: "test.txt", contentType: "text/plain", data: Data(content.utf8)))
        let body = form.build()
        let bodyStr = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyStr.contains(content))
    }

    func testContentTypeHeader() {
        let form = MultipartFormData(boundary: "MY_BOUNDARY")
        XCTAssertEqual(form.contentTypeHeader, "multipart/form-data; boundary=MY_BOUNDARY")
    }

    func testMultipleParts() {
        var form = MultipartFormData(boundary: "B")
        form.append(.init(name: "field1", filename: nil, contentType: "text/plain", data: Data("v1".utf8)))
        form.append(.init(name: "field2", filename: nil, contentType: "text/plain", data: Data("v2".utf8)))
        XCTAssertEqual(form.parts.count, 2)
        let body = form.build()
        let bodyStr = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyStr.contains("name=\"field1\""))
        XCTAssertTrue(bodyStr.contains("name=\"field2\""))
    }
}
