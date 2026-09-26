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
            throw refusal(for: url, reason: "only https and http base URLs are supported")
        }
        guard scheme == "https" || allowsInsecure || isLoopback(url) else {
            throw refusal(
                for: url,
                reason: "a plaintext base URL would send your API key in the clear. Use https, a "
                    + "loopback address, or set ClientConfiguration.allowsInsecureBaseURL = true "
                    + "to accept the risk"
            )
        }
    }

    private static func refusal(for url: URL, reason: String) -> AnthropicError {
        .networkError(URLError(
            .appTransportSecurityRequiresSecureConnection,
            userInfo: [
                NSLocalizedDescriptionKey: "Refusing to send a request to \(redactedOrigin(of: url)): \(reason).",
            ]
        ))
    }

    /// Scheme, host and port only. Deliberately not `absoluteString`: a `baseURL` may carry
    /// userinfo (`https://user:secret@host`), and this string ends up in error messages and logs.
    private static func redactedOrigin(of url: URL) -> String {
        let scheme = url.scheme ?? "?"
        let host = url.host ?? "?"
        guard let port = url.port else { return "\(scheme)://\(host)" }
        return "\(scheme)://\(host):\(port)"
    }

    /// Whether `url`'s host is this machine, and therefore whether plaintext stays on it.
    ///
    /// The exemption covers loopback and *only* loopback. A private or link-local address is not
    /// loopback: `10.0.0.1`, `192.168.1.1`, `fe80::1` and a `.local` mDNS name are all other
    /// machines on a network, and cleartext to them is cleartext on a wire somebody else can read.
    static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return isLoopbackHost(host)
    }

    /// The host test, split from ``isLoopback(_:)`` so it can be exercised on host strings that
    /// `URL.host` will not produce on this platform — notably a bracketed IPv6 literal, which
    /// Darwin unwraps before we ever see it.
    ///
    /// Matching is exact, never by substring: `localhost.evil.example` and `printer.local` are
    /// names an attacker can register or claim, and a `hasSuffix` check against a shorter tail
    /// would exempt them. Note that the comparison is on the *decoded* host — `URL.host`
    /// percent-decodes, so `%6c%6f%63%61%6c%68%6f%73%74` arrives here as `localhost`, which is
    /// correct: it resolves to loopback too.
    static func isLoopbackHost(_ rawHost: String) -> Bool {
        var host = rawHost.lowercased()

        // `URL.host` drops the brackets on an IPv6 literal on Darwin, but the textual form turns up
        // wherever a host is carried as a string. Normalise so `[::1]` and `::1` are one case.
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }

        // RFC 6761 reserves `localhost` and everything under `.localhost` for loopback.
        //
        // Darwin's resolver honours that. glibc does not resolve `*.localhost` specially, so if
        // Linux support is ever declared in Package.swift this clause becomes an exemption an
        // attacker can resolve — revisit it then rather than assuming it travels.
        if host == "localhost" || host.hasSuffix(".localhost") { return true }

        // RFC 4291: `::1` is the only IPv6 loopback address. Not a prefix test — `::2` and
        // `::ffff:10.0.0.1` both start `::` and neither is this machine.
        if host == "::1" { return true }

        return isIPv4Loopback(host)
    }

    /// True for a dotted-quad literal in `127.0.0.0/8` — the whole subnet, not just `127.0.0.1`.
    ///
    /// Exactly four octets, each one to three ASCII digits in range. The digit check is not
    /// redundant with the `UInt8` parse: `UInt8("+1")` is `1` and `UInt8("0177")` is `177`, so
    /// without it `127.+0.0.1` and `127.0177.0.1` would both read as loopback.
    private static func isIPv4Loopback(_ host: String) -> Bool {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        guard octets.allSatisfy({ octet in
            !octet.isEmpty
                && octet.count <= 3
                && octet.allSatisfy(\.isASCII)
                && octet.allSatisfy(\.isNumber)
                && UInt8(octet) != nil
        }) else { return false }
        return octets[0] == "127"
    }
}
