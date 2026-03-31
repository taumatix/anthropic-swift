import Foundation

/// The structured error body returned by the Anthropic API on error responses.
///
/// The API returns JSON like:
/// ```json
/// {
///   "type": "error",
///   "error": {
///     "type": "invalid_request_error",
///     "message": "max_tokens: field required"
///   }
/// }
/// ```
public struct APIError: Decodable, Sendable, CustomStringConvertible, Error {
    public let type: String
    public let error: ErrorDetail

    public struct ErrorDetail: Decodable, Sendable {
        /// The error type string (e.g., `"invalid_request_error"`, `"api_error"`).
        public let type: String
        /// The human-readable error message.
        public let message: String
    }

    public var description: String {
        "[\(error.type)] \(error.message)"
    }
}
