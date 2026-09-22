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

    // MARK: - Header escaping

    /// CRLF is a *single* `Character` in Swift, so a grapheme-wise `switch` against "\r" and "\n"
    /// matches neither and passes the pair straight through. `escapeHeaderValue` iterates unicode
    /// scalars for exactly this reason; this test is what caught it.
    func testEscapeRemovesCRLFIncludingThePairedGrapheme() {
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("a\r\nb"), "ab")
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("a\rb"), "ab")
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("a\nb"), "ab")
        XCTAssertEqual("a\r\nb".count, 3, "CRLF counts as one Character — the trap this guards")
    }

    func testEscapeBackslashEscapesQuotesAndBackslashes() {
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("a\"b"), "a\\\"b")
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("a\\b"), "a\\\\b")
    }

    func testEscapeLeavesOrdinaryPathsAlone() {
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("my-skill/SKILL.md"), "my-skill/SKILL.md")
        XCTAssertEqual(MultipartFormData.escapeHeaderValue("café.md"), "café.md")
    }

    /// A filename that tries to close its quoted parameter and open a new part must produce one
    /// part with one `Content-Disposition`.
    func testAHostileFilenameCannotForgeASecondPart() {
        var form = MultipartFormData(boundary: "BOUNDARY")
        form.append(.init(
            name: "files[]",
            filename: "x\";name=\"display_name\"\r\n\r\npwned\r\n--BOUNDARY\r\n",
            contentType: "text/markdown",
            data: Data("content".utf8)
        ))
        let body = String(decoding: form.build(), as: UTF8.self)

        XCTAssertEqual(body.components(separatedBy: "Content-Disposition:").count - 1, 1, body)
        XCTAssertFalse(body.contains("name=\"display_name\""), body)

        // Count delimiter *lines*. The literal text "--BOUNDARY" also survives inside the quoted
        // filename, which is harmless — what matters is that it never starts a line.
        let delimiterLines = body
            .components(separatedBy: "\r\n")
            .filter { $0 == "--BOUNDARY" || $0 == "--BOUNDARY--" }
        XCTAssertEqual(delimiterLines.count, 2,
                       "one opening and one closing delimiter\n\(body)")
    }
}
