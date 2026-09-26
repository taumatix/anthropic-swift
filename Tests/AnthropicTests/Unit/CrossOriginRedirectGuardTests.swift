import XCTest
@testable import Anthropic

/// The origin comparison the redirect guard turns on, exercised without a socket.
///
/// `CrossOriginRedirectTests` proves the guard is wired into both transports over real TCP. This
/// proves the decision itself on cases a two-listener test cannot reach: a scheme downgrade, a
/// default port written out either way, and a URL missing a piece.
final class CrossOriginRedirectGuardTests: XCTestCase {

    private func sameOrigin(_ lhs: String, _ rhs: String) -> Bool {
        CrossOriginRedirectGuard.sameOrigin(URL(string: lhs), URL(string: rhs))
    }

    // MARK: - Different origins

    func testADifferentHostIsADifferentOrigin() {
        XCTAssertFalse(sameOrigin("https://evil.example/v1", "https://api.anthropic.com"))
    }

    func testADifferentPortIsADifferentOrigin() {
        XCTAssertFalse(sameOrigin("https://api.anthropic.com:8443/v1", "https://api.anthropic.com"))
    }

    /// A same-host downgrade to cleartext is an origin change, so one rule covers it. Without this
    /// a redirect could walk an `https` base URL down to plaintext and out of `BaseURLPolicy`.
    func testASchemeDowngradeOnTheSameHostIsADifferentOrigin() {
        XCTAssertFalse(sameOrigin("http://api.anthropic.com/v1", "https://api.anthropic.com"))
    }

    /// Fail safe: an unparseable or host-less URL is not an excuse to follow a redirect.
    func testAMissingPieceIsNeverTheSameOrigin() {
        XCTAssertFalse(CrossOriginRedirectGuard.sameOrigin(URL(string: "https://a.example"), nil))
        XCTAssertFalse(CrossOriginRedirectGuard.sameOrigin(nil, URL(string: "https://a.example")))
        XCTAssertFalse(sameOrigin("mailto:someone@example.com", "https://a.example"))
    }

    // MARK: - Same origin

    func testTheSameOriginMatches() {
        XCTAssertTrue(sameOrigin("https://api.anthropic.com/v1/messages", "https://api.anthropic.com"))
    }

    /// `https://h` and `https://h:443` are one origin. Treating a written-out default port as a
    /// change would refuse a redirect that went nowhere.
    func testAnExplicitDefaultHTTPSPortIsTheSameOrigin() {
        XCTAssertTrue(sameOrigin("https://api.anthropic.com:443/v1", "https://api.anthropic.com"))
    }

    /// The http counterpart, which matters for a plaintext gateway under
    /// `allowsInsecureBaseURL`: without the `case "http": return 80` arm, `http://gw/a` →
    /// `http://gw:80/b` would be refused and the gateway would break.
    func testAnExplicitDefaultHTTPPortIsTheSameOrigin() {
        XCTAssertTrue(sameOrigin("http://gateway.internal:80/b", "http://gateway.internal/a"))
    }

    func testSchemeAndHostCompareCaseInsensitively() {
        XCTAssertTrue(sameOrigin("HTTPS://API.Anthropic.com/v1", "https://api.anthropic.com"))
    }
}
