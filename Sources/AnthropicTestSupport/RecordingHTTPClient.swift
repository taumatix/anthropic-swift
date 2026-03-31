import Foundation
import Anthropic

/// An `HTTPClient` that records requests and replays them from a mock.
///
/// Useful for snapshot/cassette-style testing: record real responses once,
/// then replay them in future test runs without hitting the network.
public final class RecordingHTTPClient: HTTPClient, @unchecked Sendable {
    public struct Recording: Sendable {
        public let request: HTTPRequest
        public let response: HTTPResponse
    }

    private var recordings: [Recording] = []
    private let lock = NSLock()

    public init() {}

    public func addRecording(_ recording: Recording) {
        lock.withLock { recordings.append(recording) }
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let recording = lock.withLock {
            recordings.first(where: { $0.request.path == request.path })
        }
        guard let recording else {
            return HTTPResponse(statusCode: 404, body: Data("{}".utf8))
        }
        return recording.response
    }

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
