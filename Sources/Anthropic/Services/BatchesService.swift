import Foundation

/// Provides access to the Message Batches API.
///
/// Access via `AnthropicClient.batches`.
public final class BatchesService: Sendable {
    private let pipeline: RequestPipeline

    init(pipeline: RequestPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Create

    /// Creates a new message batch.
    ///
    /// - Parameter request: The batch parameters, containing up to 10,000 message requests.
    public func create(_ request: BatchCreateRequest) async throws -> MessageBatch {
        let body = try JSONCoding.encoder.encode(request)
        let httpRequest = HTTPRequest(method: "POST", path: "/v1/messages/batches", body: body)
        return try await pipeline.send(httpRequest)
    }

    // MARK: - Get

    /// Returns the status and metadata of a batch.
    ///
    /// - Parameter id: The batch identifier.
    public func get(id: String) async throws -> MessageBatch {
        let request = HTTPRequest(method: "GET", path: "/v1/messages/batches/\(id)")
        return try await pipeline.send(request)
    }

    // MARK: - List

    /// Returns a paginated list of message batches.
    public func list(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) async throws -> Page<MessageBatch> {
        var queryItems = PaginationCursor(afterId: afterId, beforeId: beforeId).queryItems
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }

        let request = HTTPRequest(method: "GET", path: "/v1/messages/batches", queryItems: queryItems)
        let page: Page<MessageBatch> = try await pipeline.send(request)
        return attachFetcher(to: page)
    }

    // MARK: - Cancel

    /// Cancels a batch that is currently being processed.
    ///
    /// - Parameter id: The batch identifier.
    public func cancel(id: String) async throws -> MessageBatch {
        let request = HTTPRequest(method: "POST", path: "/v1/messages/batches/\(id)/cancel")
        return try await pipeline.send(request)
    }

    // MARK: - Delete

    /// Deletes a batch.
    ///
    /// - Parameter id: The batch identifier.
    public func delete(id: String) async throws -> BatchDeleteResponse {
        let request = HTTPRequest(method: "DELETE", path: "/v1/messages/batches/\(id)")
        return try await pipeline.send(request)
    }

    // MARK: - Results

    /// Streams the JSONL results of a completed batch.
    ///
    /// Results are streamed line by line as the server delivers them.
    /// Only available after the batch's `processingStatus` is `.ended`.
    ///
    /// ```swift
    /// for try await result in client.batches.results(id: batchId) {
    ///     switch result.result {
    ///     case .succeeded(let message): print(message.textContent)
    ///     case .errored(let error): print("Error:", error)
    ///     case .canceled, .expired: break
    ///     }
    /// }
    /// ```
    public func results(id: String) -> AsyncThrowingStream<BatchResult, Error> {
        let request = HTTPRequest(method: "GET", path: "/v1/messages/batches/\(id)/results")
        let dataStream = pipeline.stream(request)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await lineData in dataStream {
                        guard let line = String(data: lineData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                              !line.isEmpty else { continue }
                        guard let jsonData = line.data(using: .utf8) else { continue }
                        let result = try JSONCoding.decoder.decode(BatchResult.self, from: jsonData)
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Pagination

    private func attachFetcher(to page: Page<MessageBatch>) -> Page<MessageBatch> {
        let pipeline = self.pipeline
        return Page(
            data: page.data,
            hasMore: page.hasMore,
            firstId: page.firstId,
            lastId: page.lastId,
            nextPageFetcher: { afterId in
                let queryItems = [URLQueryItem(name: "after_id", value: afterId)]
                let request = HTTPRequest(method: "GET", path: "/v1/messages/batches", queryItems: queryItems)
                let nextPage: Page<MessageBatch> = try await pipeline.send(request)
                return nextPage
            }
        )
    }
}
