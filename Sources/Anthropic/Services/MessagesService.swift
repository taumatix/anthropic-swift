import Foundation

/// Provides access to the Messages API.
///
/// Access via `AnthropicClient.messages`.
public final class MessagesService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Create Message (non-streaming)

    /// Creates a message and returns the complete response.
    ///
    /// - Parameter request: The message parameters.
    /// - Returns: The complete `MessageResponse`.
    public func create(_ request: MessageRequest) async throws -> MessageResponse {
        var req = request
        req.stream = false
        let body = try JSONCoding.encoder.encode(req)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/messages", body: body)
        return try await pipeline.send(httpRequest)
    }

    // MARK: - Stream Message

    /// Creates a streaming message, returning a `MessageStream` to iterate events.
    ///
    /// The HTTP connection is established lazily when iteration begins:
    /// ```swift
    /// let stream = client.messages.stream(request)
    /// for try await event in stream { ... }
    /// ```
    ///
    /// - Parameter request: The message parameters.
    /// - Returns: A `MessageStream` to iterate `MessageStreamEvent` values.
    public func stream(_ request: MessageRequest) -> MessageStream {
        var req = request
        req.stream = true
        guard let body = try? JSONCoding.encoder.encode(req) else {
            return MessageStream(dataStream: AsyncThrowingStream { continuation in
                continuation.finish(throwing: AnthropicError.encodingError(
                    EncodingError.invalidValue(req, .init(codingPath: [], debugDescription: "Failed to encode request"))
                ))
            })
        }
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/messages", body: body)
        let dataStream = pipeline.stream(httpRequest)
        return MessageStream(dataStream: dataStream)
    }

    // MARK: - Count Tokens

    /// Counts the tokens in a request without sending it to the model.
    ///
    /// - Parameter request: The token count request parameters.
    /// - Returns: A `CountTokensResponse` with the input token count.
    public func countTokens(_ request: CountTokensRequest) async throws -> CountTokensResponse {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/messages/count_tokens", body: body)
        return try await pipeline.send(httpRequest)
    }
}
