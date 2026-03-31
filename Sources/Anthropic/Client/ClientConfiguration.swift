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
    public var baseURL: URL

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
    public var httpClient: any HTTPClient

    // MARK: - Default Configuration

    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!
    public static let defaultAnthropicVersion = "2023-06-01"

    public init(
        apiKey: String,
        adminAPIKey: String? = nil,
        baseURL: URL = defaultBaseURL,
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
        self.anthropicVersion = anthropicVersion
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.retryPolicy = retryPolicy
        self.additionalHeaders = additionalHeaders
        self.httpClient = httpClient ?? URLSessionHTTPClient()
    }
}
