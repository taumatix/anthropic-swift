import Foundation

/// The top-level error type for all errors thrown by the Anthropic Swift SDK.
///
/// Use a `switch` statement for exhaustive handling:
/// ```swift
/// do {
///     let response = try await client.messages.create(request)
/// } catch let error as AnthropicError {
///     switch error {
///     case .rateLimited(let retryAfter):
///         // Back off and retry
///     case .authenticationFailed:
///         // Check your API key
///     case .apiError(let apiError):
///         print(apiError.error.message)
///     default:
///         break
///     }
/// }
/// ```
public enum AnthropicError: Error, Sendable, CustomStringConvertible {
    /// The API returned a structured error body (4xx/5xx with parseable JSON).
    case apiError(APIError)

    /// An HTTP error occurred but the body could not be decoded as `APIError`.
    case httpError(statusCode: Int, body: Data?)

    /// A network-level failure (e.g., no connection, timeout from URLSession).
    case networkError(URLError)

    /// The request could not be encoded.
    case encodingError(EncodingError)

    /// The response body could not be decoded.
    case decodingError(DecodingError, rawBody: Data)

    /// The SSE stream could not be parsed.
    case streamParseError(String)

    /// The request timed out.
    case timeout

    /// The API returned HTTP 429 (rate limited).
    case rateLimited(retryAfter: TimeInterval?)

    /// The API key is missing or invalid (HTTP 401).
    case authenticationFailed

    /// The API key does not have permission for this operation (HTTP 403).
    case permissionDenied

    public var description: String {
        switch self {
        case .apiError(let e): return "AnthropicError.apiError: \(e)"
        case .httpError(let code, _): return "AnthropicError.httpError(\(code))"
        case .networkError(let e): return "AnthropicError.networkError: \(e.localizedDescription)"
        case .encodingError(let e): return "AnthropicError.encodingError: \(e)"
        case .decodingError(let e, _): return "AnthropicError.decodingError: \(e)"
        case .streamParseError(let msg): return "AnthropicError.streamParseError: \(msg)"
        case .timeout: return "AnthropicError.timeout"
        case .rateLimited(let retryAfter):
            if let t = retryAfter { return "AnthropicError.rateLimited(retryAfter: \(t)s)" }
            return "AnthropicError.rateLimited"
        case .authenticationFailed: return "AnthropicError.authenticationFailed"
        case .permissionDenied: return "AnthropicError.permissionDenied"
        }
    }
}

// MARK: - HTTP Status Mapping

extension AnthropicError {
    /// Maps an HTTP response to the appropriate `AnthropicError`.
    static func from(response: HTTPResponse) -> AnthropicError {
        switch response.statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .permissionDenied
        case 429:
            return .rateLimited(retryAfter: response.retryAfter)
        default:
            if let apiError = try? JSONCoding.decoder.decode(APIError.self, from: response.body) {
                return .apiError(apiError)
            }
            return .httpError(statusCode: response.statusCode, body: response.body)
        }
    }
}
