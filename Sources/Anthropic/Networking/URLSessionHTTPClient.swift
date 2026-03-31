import Foundation

/// Production `HTTPClient` implementation backed by `URLSession`.
///
/// Uses `URLSession.data(for:)` for non-streaming requests and
/// `URLSession.bytes(for:)` for streaming (SSE) requests.
public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Note: baseURL is set by RequestPipeline before calling this method.
        // The request passed here already has the full URLRequest built.
        // We accept pre-built URLRequest via a different path — see RequestPipeline.
        fatalError("URLSessionHTTPClient.send(_:HTTPRequest) should not be called directly. Use RequestPipeline.")
    }

    /// Sends a pre-built `URLRequest` and returns the response.
    func send(urlRequest: URLRequest) async throws -> HTTPResponse {
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

    /// Sends a pre-built `URLRequest` and returns a stream of raw data chunks.
    func stream(urlRequest: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
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

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        fatalError("URLSessionHTTPClient.stream(_:HTTPRequest) should not be called directly. Use RequestPipeline.")
    }

    private func makeResponse(data: Data, urlResponse: URLResponse) throws -> HTTPResponse {
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AnthropicError.httpError(statusCode: 0, body: data)
        }
        let headers = (httpResponse.allHeaderFields as? [String: String]) ?? [:]
        return HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: data)
    }
}
