import XCTest
@testable import Anthropic

/// `baseURL` decides where the SDK sends the caller's API key, and until this policy existed
/// nothing checked that the destination could keep it secret.
///
/// An app that reads its endpoint from config or an environment variable can be handed
/// `http://gateway` by whoever controls that value, and the key then goes out in cleartext. The
/// loopback exemption exists because the end-to-end tests here are genuinely `http://127.0.0.1`,
/// so it has to be narrow enough not to be a bypass.
final class BaseURLPolicyTests: XCTestCase {

    private func refuses(_ string: String, allowsInsecure: Bool = false,
                         file: StaticString = #filePath, line: UInt = #line) {
        guard let url = URL(string: string) else {
            return XCTFail("not a URL: \(string)", file: file, line: line)
        }
        XCTAssertThrowsError(try BaseURLPolicy.validate(url, allowsInsecure: allowsInsecure),
                             "expected \(string) to be refused", file: file, line: line) { error in
            guard case AnthropicError.networkError(let urlError) = error else {
                return XCTFail("expected .networkError, got \(error)", file: file, line: line)
            }
            XCTAssertEqual(urlError.code, .appTransportSecurityRequiresSecureConnection,
                           "the refusal should say why", file: file, line: line)
        }
    }

    private func allows(_ string: String, allowsInsecure: Bool = false,
                        file: StaticString = #filePath, line: UInt = #line) {
        guard let url = URL(string: string) else {
            return XCTFail("not a URL: \(string)", file: file, line: line)
        }
        XCTAssertNoThrow(try BaseURLPolicy.validate(url, allowsInsecure: allowsInsecure),
                         "expected \(string) to be allowed", file: file, line: line)
    }

    // MARK: - Refused

    func testAPlaintextHostIsRefused() {
        refuses("http://gateway.internal.example")
    }

    func testANonHTTPSchemeIsRefused() {
        refuses("ftp://api.anthropic.com")
        refuses("file:///tmp/responses")
    }

    /// The exemption is for the loopback *host*, not for any name that contains it. Matching by
    /// substring would let an attacker register `localhost.evil.example` and be exempt.
    func testALookalikeLoopbackNameIsRefused() {
        refuses("http://localhost.evil.example")
        refuses("http://notlocalhost")
        refuses("http://127.0.0.1.evil.example")
    }

    /// `127.0.0.1` is loopback; `127.0.0.1` with something appended in the last octet is not a
    /// literal at all, and neither are the near-misses that look like one.
    func testNearMissAddressesAreRefused() {
        refuses("http://127.0.0.256")
        refuses("http://12.7.0.1")
        refuses("http://0.0.0.0")
    }

    // MARK: - Allowed

    func testHTTPSIsAllowedAnywhere() {
        allows("https://api.anthropic.com")
        allows("https://gateway.internal.example:8443")
    }

    func testLoopbackOverPlaintextIsAllowed() {
        allows("http://127.0.0.1:8080")
        allows("http://localhost:8080")
        allows("http://[::1]:8080")
    }

    /// All of `127.0.0.0/8` is loopback, not just `.1`.
    func testTheWholeLoopbackSubnetIsAllowed() {
        allows("http://127.0.0.2")
        allows("http://127.1.2.3:9000")
    }

    /// RFC 6761 reserves `.localhost` for loopback, and test harnesses use it.
    func testADotLocalhostNameIsAllowed() {
        allows("http://anthropic.localhost:8080")
    }

    func testHostComparisonIsCaseInsensitive() {
        allows("HTTP://LOCALHOST:8080")
    }

    // MARK: - Opt out

    /// A caller with an internal plaintext gateway can say so. Refusing with no way forward pushes
    /// them off the SDK rather than onto a secure endpoint; making them write it down keeps the
    /// choice visible in their code.
    func testTheOptOutPermitsPlaintext() {
        allows("http://gateway.internal.example", allowsInsecure: true)
    }

    /// The opt-out is about transport security, not about turning `baseURL` into anything at all.
    func testTheOptOutDoesNotPermitANonHTTPScheme() {
        refuses("file:///tmp/responses", allowsInsecure: true)
    }
}
