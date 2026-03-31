import XCTest
@testable import Anthropic

final class RetryPolicyTests: XCTestCase {

    let policy = RetryPolicy.default

    func testRetryableStatusCodes() {
        for code in [429, 500, 502, 503, 529] {
            let response = HTTPResponse(statusCode: code, body: Data())
            XCTAssertTrue(policy.shouldRetry(response: response, attempt: 0, maxRetries: 2),
                          "Expected \(code) to be retryable")
        }
    }

    func testNonRetryableStatusCodes() {
        for code in [400, 401, 403, 404, 422] {
            let response = HTTPResponse(statusCode: code, body: Data())
            XCTAssertFalse(policy.shouldRetry(response: response, attempt: 0, maxRetries: 2),
                           "Expected \(code) to NOT be retryable")
        }
    }

    func testMaxRetriesExceededReturnsFalse() {
        let response = HTTPResponse(statusCode: 500, body: Data())
        XCTAssertFalse(policy.shouldRetry(response: response, attempt: 2, maxRetries: 2))
    }

    func testExponentialBackoffDelayCalculation() {
        let p = RetryPolicy(
            strategy: .exponentialBackoff(base: 1.0, multiplier: 2.0, maxDelay: 30.0),
            retryableStatusCodes: [500]
        )
        let response = HTTPResponse(statusCode: 500, body: Data())
        XCTAssertEqual(p.delay(for: response, attempt: 0), 1.0)   // 1 * 2^0 = 1
        XCTAssertEqual(p.delay(for: response, attempt: 1), 2.0)   // 1 * 2^1 = 2
        XCTAssertEqual(p.delay(for: response, attempt: 2), 4.0)   // 1 * 2^2 = 4
        XCTAssertEqual(p.delay(for: response, attempt: 10), 30.0) // capped at maxDelay
    }

    func testRetryAfterHeaderUsedFor429() {
        let response = HTTPResponse(statusCode: 429, headers: ["retry-after": "15"], body: Data())
        XCTAssertEqual(policy.delay(for: response, attempt: 0), 15.0)
    }

    func testNoDelayForNoneStrategy() {
        let p = RetryPolicy(strategy: .none, retryableStatusCodes: [500])
        let response = HTTPResponse(statusCode: 500, body: Data())
        XCTAssertEqual(p.delay(for: response, attempt: 0), 0.0)
    }
}
