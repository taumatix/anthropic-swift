import Foundation

/// Production `HTTPClient` implementation backed by `URLSession`.
///
/// Uses `URLSession.data(for:delegate:)` for non-streaming requests and
/// `URLSession.bytes(for:delegate:)` for streaming (SSE) requests.
///
/// Both pass ``RedirectCredentialGuard`` as a *task* delegate, which is what lets the guard work
/// on `URLSession.shared` — a session-level delegate can only be set at session construction, and
/// `.shared` does not accept one. A caller who injects their own `URLSession` keeps its
/// configuration and its session delegate; note that a session delegate of theirs implementing
/// `willPerformHTTPRedirection` will not be consulted for these tasks, because a task delegate
/// takes precedence.
///
/// The `baseURL` is required so this client can properly implement the
/// `HTTPClient` protocol by building `URLRequest` values itself, without
/// needing an out-of-band call path from `RequestPipeline`.
public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    let baseURL: URL

    /// The caller's explicit opt-in to a plaintext `baseURL`. See ``BaseURLPolicy``.
    let allowsInsecureBaseURL: Bool

    public init(
        session: URLSession = .shared,
        baseURL: URL = ClientConfiguration.defaultBaseURL,
        allowsInsecureBaseURL: Bool = false
    ) {
        self.session = session
        self.baseURL = baseURL
        self.allowsInsecureBaseURL = allowsInsecureBaseURL
    }

    /// Returns a copy pointed at `baseURL` under `allowsInsecureBaseURL`, keeping this client's
    /// `URLSession`.
    ///
    /// Lets `ClientConfiguration` honour a change to either without discarding a session the
    /// caller configured for TLS pinning or a proxy.
    func reconfigured(baseURL: URL, allowsInsecureBaseURL: Bool) -> URLSessionHTTPClient {
        guard baseURL != self.baseURL || allowsInsecureBaseURL != self.allowsInsecureBaseURL else {
            return self
        }
        return URLSessionHTTPClient(
            session: session,
            baseURL: baseURL,
            allowsInsecureBaseURL: allowsInsecureBaseURL
        )
    }

    /// Builds the `URLRequest`, refusing first if `baseURL` cannot carry a credential.
    ///
    /// The check is here rather than on assignment because `ClientConfiguration.baseURL` is a
    /// stored property and `didSet` cannot throw. Doing it per request also means a configuration
    /// that is never used to send anything never refuses.
    private func validatedURLRequest(for request: HTTPRequest) throws -> URLRequest {
        try BaseURLPolicy.validate(baseURL, allowsInsecure: allowsInsecureBaseURL)
        return try request.urlRequest(baseURL: baseURL)
    }

    // MARK: - HTTPClient

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = try validatedURLRequest(for: request)
        do {
            // The delegate is per-task, not per-session, which is why this works on
            // `URLSession.shared` — a session created elsewhere (a caller's pinned or proxied one)
            // keeps its own delegate and still gets the redirect guard.
            let (data, urlResponse) = try await session.data(
                for: urlRequest,
                delegate: RedirectCredentialGuard.shared
            )
            return try makeResponse(data: data, urlResponse: urlResponse)
        } catch let error as URLError {
            if error.code == .timedOut {
                throw AnthropicError.timeout
            }
            throw AnthropicError.networkError(error)
        }
    }

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        // `try?` here used to discard whatever was thrown and substitute an `encodingError` about
        // the path, which would now report a refused `baseURL` as a serialisation bug. Report what
        // actually happened; `urlRequest(baseURL:)` already throws the path error itself.
        let urlRequest: URLRequest
        do {
            urlRequest = try validatedURLRequest(for: request)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (asyncBytes, urlResponse) = try await self.session.bytes(
                        for: urlRequest,
                        delegate: RedirectCredentialGuard.shared
                    )
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
