import Foundation

/// Provides API keys for authenticating requests.
///
/// The default implementation uses a static key. Custom implementations can
/// fetch keys from the keychain, environment variables, or remote configuration.
public protocol APIKeyProvider: Sendable {
    /// The API key for standard API requests.
    var apiKey: String { get }
    /// An optional separate key for the Admin/Organization API.
    /// If `nil`, the standard `apiKey` is used for admin requests.
    var adminAPIKey: String? { get }
}

// MARK: - Default Implementation

extension APIKeyProvider {
    public var adminAPIKey: String? { nil }
}

// MARK: - Concrete Types

/// A simple `APIKeyProvider` backed by static string values.
public struct StaticAPIKeyProvider: APIKeyProvider {
    public let apiKey: String
    public let adminAPIKey: String?

    public init(apiKey: String, adminAPIKey: String? = nil) {
        self.apiKey = apiKey
        self.adminAPIKey = adminAPIKey
    }
}

/// An `APIKeyProvider` that reads the key from an environment variable.
public struct EnvironmentAPIKeyProvider: APIKeyProvider {
    private let variableName: String
    private let adminVariableName: String?

    public init(variableName: String = "ANTHROPIC_API_KEY", adminVariableName: String? = nil) {
        self.variableName = variableName
        self.adminVariableName = adminVariableName
    }

    public var apiKey: String {
        ProcessInfo.processInfo.environment[variableName] ?? ""
    }

    public var adminAPIKey: String? {
        adminVariableName.flatMap { ProcessInfo.processInfo.environment[$0] }
    }
}
