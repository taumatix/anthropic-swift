import Foundation

/// Production `HTTPClient` implementation backed by `URLSession`.
///
/// Uses `URLSession.data(for:)` for non-streaming requests and
/// `URLSession.bytes(for:)` for streaming (SSE) requests.
///
/// The `baseURL` is required so this client can properly implement the
/// `HTTPClient` protocol by building `URLRequest` values itself, without
/// needing an out-of-band call path from `RequestPipeline`.
public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    let baseURL: URL

    public init(session: URLSession = .shared, baseURL: URL = ClientConfiguration.defaultBaseURL) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - HTTPClient

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = try request.urlRequest(baseURL: baseURL)
        do {
            let (data, urlResponse) = try await session.data(for: urlRequest)
            return try makeResponse(data: data, urlResponse: urlResponse)
        } catch let error as URLError {
            if error.code == .timedOut {
                throw AnthropicError.timeout
            }
            throw AnthropicError.networkError(error)
        }
    }

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        guard let urlRequest = try? request.urlRequest(baseURL: baseURL) else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AnthropicError.encodingError(
                    EncodingError.invalidValue(
                        request.path,
                        .init(codingPath: [], debugDescription: "Could not build URL from path: \(request.path)")
                    )
                ))
            }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (asyncBytes, urlResponse) = try await self.session.bytes(for: urlRequest)
                    // Validate status before streaming
                    if let httpResponse = urlResponse as? HTTPURLResponse,
                       !(200..<300).contains(httpResponse.statusCode) {
                        var collected = Data()
                        for try await byte in asyncBytes {
                            collected.append(byte)
                        }
                        let headers = (httpResponse.allHeaderFields as? [String: String]) ?? [:]
                        let resp = HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: collected)
                        continuation.finish(throwing: AnthropicError.from(response: resp))
                        return
                    }
                    // Stream line-by-line chunks
                    var lineBuffer = Data()
                    for try await byte in asyncBytes {
                        lineBuffer.append(byte)
                        // Deliver on newline boundaries for SSE
                        if byte == UInt8(ascii: "\n") {
                            continuation.yield(lineBuffer)
                            lineBuffer = Data()
                        }
                    }
                    // Yield any remaining data
                    if !lineBuffer.isEmpty {
                        continuation.yield(lineBuffer)
                    }
                    continuation.finish()
                } catch let error as URLError {
                    if error.code == .timedOut {
                        continuation.finish(throwing: AnthropicError.timeout)
                    } else {
                        continuation.finish(throwing: AnthropicError.networkError(error))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private func makeResponse(data: Data, urlResponse: URLResponse) throws -> HTTPResponse {
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AnthropicError.httpError(statusCode: 0, body: data)
        }
        let headers = (httpResponse.allHeaderFields as? [String: String]) ?? [:]
        return HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: data)
    }
}
