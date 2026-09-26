import XCTest
@testable import Anthropic

/// The origin comparison the redirect guard turns on, exercised without a socket.
///
/// `RedirectCredentialTests` proves the guard is wired into both transports over real TCP. This
/// proves the decision itself on the cases a two-listener test cannot reach: a scheme downgrade, a
/// default port written out, and a redirect whose URL is missing a piece.
final class RedirectCredentialGuardTests: XCTestCase {

    private static let origin = URL(string: "https://api.anthropic.com")!

    private func sanitizedHeaders(
        to target: String,
        from origin: URL? = RedirectCredentialGuardTests.origin,
        headers: [String: String] = ["x-api-key": "sk-test", "anthropic-version": "2023-06-01"]
    ) throws -> [String: String] {
        var request = URLRequest(url: try XCTUnwrap(URL(string: target)))
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let sanitized = RedirectCredentialGuard.sanitize(request, origin: origin)
        return sanitized.allHTTPHeaderFields ?? [:]
    }

    // MARK: - Stripped

    func testADifferentHostIsStripped() throws {
        XCTAssertNil(try sanitizedHeaders(to: "https://evil.example/v1/messages")["x-api-key"])
    }

    func testADifferentPortIsStripped() throws {
        XCTAssertNil(try sanitizedHeaders(to: "https://api.anthropic.com:8443/v1")["x-api-key"])
    }

    /// A same-host downgrade to cleartext is an origin change, so one rule covers it. Without this
    /// the key would be replayed over plaintext to the very host the caller trusts.
    func testASchemeDowngradeOnTheSameHostIsStripped() throws {
        XCTAssertNil(try sanitizedHeaders(to: "http://api.anthropic.com/v1")["x-api-key"])
    }

    /// A caller's gateway token lives in `ClientOptions.additionalHeaders` and is exactly the kind
    /// of secret a denylist of known Anthropic headers would miss. The allowlist is why it does not.
    func testACallerSuppliedHeaderIsStrippedToo() throws {
        let headers = try sanitizedHeaders(
            to: "https://evil.example/v1",
            headers: ["x-api-key": "sk-test", "x-gateway-token": "caller-secret"]
        )
        XCTAssertNil(headers["x-gateway-token"])
    }

    /// Fail safe: an unparseable target is not an excuse to send credentials to it.
    func testAMissingOriginIsStripped() throws {
        XCTAssertNil(try sanitizedHeaders(to: "https://api.anthropic.com/v1", from: nil)["x-api-key"])
    }

    /// The companion to every assertion above: the headers have to have been there to be removed.
    func testTheStrippedRequestKeepsItsHopSafeHeaders() throws {
        let headers = try sanitizedHeaders(
            to: "https://evil.example/v1",
            headers: ["x-api-key": "sk-test", "Accept": "application/json"]
        )
        XCTAssertNil(headers["x-api-key"])
        XCTAssertEqual(headers["Accept"], "application/json",
                       "content negotiation is not a credential and must survive")
    }

    // MARK: - Kept

    func testTheSameOriginKeepsEverything() throws {
        let headers = try sanitizedHeaders(to: "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(headers["x-api-key"], "sk-test")
        XCTAssertEqual(headers["anthropic-version"], "2023-06-01")
    }

    /// `https://h` and `https://h:443` are the same origin. Treating the written-out default port
    /// as a change would strip on a redirect that went nowhere.
    func testAnExplicitDefaultPortIsTheSameOrigin() throws {
        XCTAssertEqual(try sanitizedHeaders(to: "https://api.anthropic.com:443/v1")["x-api-key"],
                       "sk-test")
    }

    func testSchemeAndHostCompareCaseInsensitively() throws {
        XCTAssertEqual(try sanitizedHeaders(to: "HTTPS://API.Anthropic.com/v1")["x-api-key"],
                       "sk-test")
    }
}
