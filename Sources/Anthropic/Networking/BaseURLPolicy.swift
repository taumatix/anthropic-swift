import Foundation

/// Decides whether a `baseURL` is somewhere the SDK is willing to send an API key.
///
/// `baseURL` began routing traffic on 2026-09-22; before that it was ignored, so where it pointed
/// did not matter. It does now. An app that reads its endpoint from configuration or an environment
/// variable can be handed `http://gateway` by whoever controls that value, and `x-api-key` then
/// crosses the network in cleartext.
///
/// On Apple platforms App Transport Security would refuse most of these loads itself — but ATS is
/// the app's policy, waivable with `NSAllowsArbitraryLoads`, and an SDK holding a credential should
/// not delegate that decision to a plist it does not own. Hence the same refusal, spelled the same
/// way: `URLError.appTransportSecurityRequiresSecureConnection`.
enum BaseURLPolicy {

    /// Throws unless `url` can carry a credential.
    ///
    /// - Parameter allowsInsecure: the caller's explicit opt-in to plaintext, from
    ///   ``ClientConfiguration/allowsInsecureBaseURL``. It waives the `https` requirement and
    ///   nothing else.
    static func validate(_ url: URL, allowsInsecure: Bool) throws {
        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else {
            throw refusal
        }
        guard scheme == "https" || allowsInsecure || isLoopback(url) else {
            throw refusal
        }
    }

    private static var refusal: AnthropicError {
        .networkError(URLError(.appTransportSecurityRequiresSecureConnection))
    }

    /// Whether `url`'s host is this machine, and therefore whether plaintext stays on it.
    ///
    /// Matching is exact, never by substring: `localhost.evil.example` is a name an attacker can
    /// register, and a `hasSuffix("localhost")` check would exempt it.
    static func isLoopback(_ url: URL) -> Bool {
        guard var host = url.host?.lowercased() else { return false }

        // `URL.host` keeps the brackets on an IPv6 literal on some platforms and drops them on
        // others. Normalise so `[::1]` and `::1` are one case.
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }

        // RFC 6761: `localhost` and anything under `.localhost` resolve to loopback.
        if host == "localhost" || host.hasSuffix(".localhost") { return true }

        // RFC 4291: `::1` is the only IPv6 loopback address.
        if host == "::1" { return true }

        return isIPv4Loopback(host)
    }

    /// True for a dotted-quad literal in `127.0.0.0/8` — the whole subnet, not just `127.0.0.1`.
    ///
    /// Every octet has to parse as a number in range, so `127.0.0.256` is not an address and
    /// `127.0.0.1.evil.example` is not one either.
    private static func isIPv4Loopback(_ host: String) -> Bool {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        guard octets.allSatisfy({ UInt8($0) != nil }) else { return false }
        return octets[0] == "127"
    }
}
