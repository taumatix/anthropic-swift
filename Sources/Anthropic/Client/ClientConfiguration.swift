import Foundation

/// All configuration settings for `AnthropicClient`.
///
/// Construct via `ClientConfiguration(apiKey:)` for defaults, or customize
/// individual properties before passing to `AnthropicClient(configuration:)`.
public struct ClientConfiguration: Sendable {
    /// The API key used for authentication.
    public var apiKey: String

    /// An optional separate key for the Admin/Organization API.
    /// If `nil`, `apiKey` is used for admin requests as well.
    public var adminAPIKey: String?

    /// The base URL for all API requests. Default: `https://api.anthropic.com`.
    ///
    /// Changing this retargets any `URLSessionHTTPClient`, including one the caller supplied —
    /// injecting a client is the only way to provide a custom `URLSession`, so a pinned or
    /// proxied session must not cost you the ability to set `baseURL`. The retarget preserves that
    /// session. A client of some other type does its own routing and is left alone.
    public var baseURL: URL {
        didSet { retargetStoredHTTPClient() }
    }

    /// Permits a `baseURL` that is not `https` and not loopback. Default: `false`.
    ///
    /// The SDK authenticates with an `x-api-key` header, so a plaintext endpoint puts the caller's
    /// key on the wire in the clear. Refusing outright would strand anyone with an internal
    /// plaintext gateway, so the choice is available — but it has to be written down in their code
    /// rather than arrived at by whatever value configuration happened to supply for `baseURL`.
    ///
    /// Loopback (`127.0.0.0/8`, `::1`, `localhost`, `*.localhost`) never needs this; plaintext
    /// there does not leave the machine. This waives the transport requirement and nothing else —
    /// a `file:` or `ftp:` `baseURL` is still refused.
    public var allowsInsecureBaseURL: Bool {
        didSet { retargetStoredHTTPClient() }
    }

    /// The Anthropic API version header value. Default: `"2023-06-01"`.
    public var anthropicVersion: String

    /// Request timeout in seconds. Default: `600` (10 minutes, for streaming).
    public var timeout: TimeInterval

    /// Maximum number of retry attempts for retryable errors. Default: `2`.
    public var maxRetries: Int

    /// The retry policy determining when and how to retry failed requests.
    public var retryPolicy: RetryPolicy

    /// Additional headers merged into every request.
    public var additionalHeaders: [String: String]

    /// The HTTP client used for networking. Override in tests with `MockHTTPClient`.
    ///
    /// A `URLSessionHTTPClient` assigned here is still retargeted by a later ``baseURL`` change,
    /// with its `URLSession` preserved. Any other client keeps its own routing.
    public var httpClient: any HTTPClient {
        get { storedHTTPClient }
        set { storedHTTPClient = newValue }
    }

    private var storedHTTPClient: any HTTPClient

    /// Rebuilds an SDK-owned `URLSessionHTTPClient` after a change to where it points or to what
    /// it will accept. A client of another type does its own routing and is left alone.
    private mutating func retargetStoredHTTPClient() {
        if let retargetable = storedHTTPClient as? URLSessionHTTPClient {
            storedHTTPClient = retargetable.reconfigured(
                baseURL: baseURL,
                allowsInsecureBaseURL: allowsInsecureBaseURL
            )
        }
    }

    // MARK: - Default Configuration

    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!
    public static let defaultAnthropicVersion = "2023-06-01"

    public init(
        apiKey: String,
        adminAPIKey: String? = nil,
        baseURL: URL = defaultBaseURL,
        allowsInsecureBaseURL: Bool = false,
        anthropicVersion: String = defaultAnthropicVersion,
        timeout: TimeInterval = 600,
        maxRetries: Int = 2,
        retryPolicy: RetryPolicy = .default,
        additionalHeaders: [String: String] = [:],
        httpClient: (any HTTPClient)? = nil
    ) {
        self.apiKey = apiKey
        self.adminAPIKey = adminAPIKey
        self.baseURL = baseURL
        self.allowsInsecureBaseURL = allowsInsecureBaseURL
        self.anthropicVersion = anthropicVersion
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.retryPolicy = retryPolicy
        self.additionalHeaders = additionalHeaders
        // An injected URLSessionHTTPClient is retargeted to `baseURL` here too, so
        // `init(baseURL:httpClient:)` cannot produce a client pointed somewhere else.
        if let injected = httpClient as? URLSessionHTTPClient {
            self.storedHTTPClient = injected.reconfigured(
                baseURL: baseURL,
                allowsInsecureBaseURL: allowsInsecureBaseURL
            )
        } else {
            self.storedHTTPClient = httpClient ?? URLSessionHTTPClient(
                baseURL: baseURL,
                allowsInsecureBaseURL: allowsInsecureBaseURL
            )
        }
    }
}
