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

    /// Exactly four octets. Without the count and empty-subsequence rules, `127.0.0.1.2` and
    /// `127..0.0.1` both read as loopback.
    func testAnAddressThatIsNotExactlyFourOctetsIsRefused() {
        refuses("http://127.0.0.1.2")
        refuses("http://127..0.0.1")
        refuses("http://127.0.0")
    }

    /// `UInt8("+1")` is 1 and `UInt8("0177")` is 177, so the digit check is not redundant with the
    /// range parse.
    func testAnOctetThatIsNotPlainDigitsIsRefused() {
        refuses("http://127.+0.0.1")
        refuses("http://127.0.0.+1")
        refuses("http://127.0177.0.1")
    }

    /// **A private address is not loopback.** Cleartext to another machine on a LAN is cleartext
    /// on a wire someone else can read, so the exemption must not widen to `10/8`, `192.168/16`,
    /// link-local, or mDNS names.
    func testPrivateAndLinkLocalAddressesAreRefused() {
        refuses("http://10.0.0.1")
        refuses("http://192.168.1.1")
        refuses("http://172.16.0.1")
        refuses("http://169.254.1.1")
        refuses("http://printer.local")
        refuses("http://somehost.lan")
    }

    /// `::1` is the only IPv6 loopback. A prefix test on `::` would exempt these.
    func testOtherIPv6AddressesAreRefused() {
        refuses("http://[::2]")
        refuses("http://[fe80::1]")
        refuses("http://[::ffff:127.0.0.1]")
        refuses("http://[::ffff:10.0.0.1]")
    }

    /// Fail closed when there is no host to judge.
    func testAURLWithNoHostIsRefused() {
        refuses("http:///v1/messages")
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

    /// `URL.host` unwraps a bracketed IPv6 literal on Darwin, so `isLoopback(_:)` never sees one.
    /// The normalising branch is still there for a host carried as a string; test it where it is
    /// reachable rather than leaving it as code no test can enter.
    func testTheHostTestNormalisesABracketedIPv6Literal() {
        XCTAssertTrue(BaseURLPolicy.isLoopbackHost("[::1]"))
        XCTAssertTrue(BaseURLPolicy.isLoopbackHost("::1"))
        XCTAssertFalse(BaseURLPolicy.isLoopbackHost("[::2]"))
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
