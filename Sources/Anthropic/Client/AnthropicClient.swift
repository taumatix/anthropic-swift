import Foundation

/// The main entry point for the Anthropic Swift SDK.
///
/// Create a client with your API key and access services via properties:
/// ```swift
/// let client = AnthropicClient(apiKey: "sk-ant-...")
///
/// // Send a message
/// let response = try await client.messages.create(
///     MessageRequest(model: .claude4Sonnet, messages: [.user("Hello!")], maxTokens: 1024)
/// )
/// print(response.textContent)
///
/// // Stream a response
/// for try await text in client.messages.stream(request).textStream {
///     print(text, terminator: "")
/// }
/// ```
///
/// - Note: `AnthropicClient` is `final class` (not `actor`) because all its properties
///   are immutable after initialization and `URLSession` manages its own concurrency.
///   See ADR-0002 for the rationale.
public final class AnthropicClient: Sendable {
    // MARK: - Services

    /// Access to the Messages API (create, stream, count tokens).
    public let messages: MessagesService
    /// Access to the Message Batches API.
    public let batches: BatchesService
    /// Access to the Models API.
    public let models: ModelsService
    /// Access to the Files API (beta).
    public let files: FilesService
    /// Access to the Skills API (beta).
    public let skills: SkillsService
    /// Access to the Admin/Organization API.
    public let admin: AdminServices

    // MARK: - Init

    /// Creates a client with an API key and optional custom options.
    ///
    /// - Parameters:
    ///   - apiKey: Your Anthropic API key.
    ///   - options: Additional configuration. Defaults to `ClientOptions(apiKey:)`.
    public convenience init(apiKey: String, options: ClientOptions? = nil) {
        var opts = options ?? ClientOptions(apiKey: apiKey)
        opts.configuration.apiKey = apiKey
        self.init(configuration: opts.configuration)
    }

    /// Creates a client with a fully customized `ClientConfiguration`.
    ///
    /// Use this when you need to inject a mock HTTP client for testing:
    /// ```swift
    /// let mock = MockHTTPClient()
    /// let config = ClientConfiguration(apiKey: "test-key", httpClient: mock)
    /// let client = AnthropicClient(configuration: config)
    /// ```
    public init(configuration: ClientConfiguration) {
        let pipeline = RequestPipeline(configuration: configuration)
        self.messages = MessagesService(pipeline: pipeline)
        self.batches = BatchesService(pipeline: pipeline)
        self.models = ModelsService(pipeline: pipeline)
        self.files = FilesService(pipeline: pipeline)
        self.skills = SkillsService(pipeline: pipeline)
        self.admin = AdminServices(pipeline: pipeline)
    }
}

// MARK: - Admin Services Namespace

/// Namespace grouping all Admin/Organization API services.
public final class AdminServices: Sendable {
    /// Access to the Workspaces API.
    public let workspaces: WorkspacesService
    /// Access to the API Keys API.
    public let apiKeys: APIKeysService
    /// Access to the Members API.
    public let members: MembersService
    /// Access to the Invites API.
    public let invites: InvitesService

    init(pipeline: RequestPipeline) {
        self.workspaces = WorkspacesService(pipeline: pipeline)
        self.apiKeys = APIKeysService(pipeline: pipeline)
        self.members = MembersService(pipeline: pipeline)
        self.invites = InvitesService(pipeline: pipeline)
    }
}
