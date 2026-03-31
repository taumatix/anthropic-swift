import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class ErrorMappingTests: XCTestCase {

    func testHTTP401MapsToAuthenticationFailed() throws {
        let response = HTTPResponse(statusCode: 401, body: MockResponses.authError)
        let error = AnthropicError.from(response: response)
        if case .authenticationFailed = error { /* pass */ } else {
            XCTFail("Expected .authenticationFailed, got \(error)")
        }
    }

    func testHTTP403MapsToPermissionDenied() throws {
        let response = HTTPResponse(statusCode: 403, body: Data())
        let error = AnthropicError.from(response: response)
        if case .permissionDenied = error { /* pass */ } else {
            XCTFail("Expected .permissionDenied, got \(error)")
        }
    }

    func testHTTP429WithRetryAfterHeader() throws {
        let response = HTTPResponse(
            statusCode: 429,
            headers: ["retry-after": "10"],
            body: MockResponses.rateLimitError
        )
        let error = AnthropicError.from(response: response)
        if case .rateLimited(let retryAfter) = error {
            XCTAssertEqual(retryAfter, 10.0)
        } else {
            XCTFail("Expected .rateLimited, got \(error)")
        }
    }

    func testHTTP429WithoutRetryAfterHeader() throws {
        let response = HTTPResponse(statusCode: 429, body: MockResponses.rateLimitError)
        let error = AnthropicError.from(response: response)
        if case .rateLimited(let retryAfter) = error {
            XCTAssertNil(retryAfter)
        } else {
            XCTFail("Expected .rateLimited, got \(error)")
        }
    }

    func testHTTP400WithParsableBodyMapsToAPIError() throws {
        let response = HTTPResponse(statusCode: 400, body: MockResponses.invalidRequestError)
        let error = AnthropicError.from(response: response)
        if case .apiError(let apiError) = error {
            XCTAssertEqual(apiError.error.type, "invalid_request_error")
        } else {
            XCTFail("Expected .apiError, got \(error)")
        }
    }

    func testHTTP400WithUnparsableBodyMapsToHTTPError() throws {
        let response = HTTPResponse(statusCode: 400, body: Data("not json".utf8))
        let error = AnthropicError.from(response: response)
        if case .httpError(let code, _) = error {
            XCTAssertEqual(code, 400)
        } else {
            XCTFail("Expected .httpError, got \(error)")
        }
    }

    func testRetryAfterHeader() {
        let response = HTTPResponse(statusCode: 200, headers: ["retry-after": "30"], body: Data())
        XCTAssertEqual(response.retryAfter, 30.0)
    }

    func testRequestIDHeader() {
        let response = HTTPResponse(statusCode: 200, headers: ["request-id": "req_123"], body: Data())
        XCTAssertEqual(response.requestID, "req_123")
    }
}
