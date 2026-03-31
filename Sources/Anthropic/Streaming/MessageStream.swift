import Foundation

/// An `AsyncSequence` of `MessageStreamEvent` values from a streaming message request.
///
/// `MessageStream` is lazy: the HTTP connection is not opened until iteration begins.
///
/// ```swift
/// let stream = client.messages.stream(request)
///
/// // Iterate all events
/// for try await event in stream { ... }
///
/// // Or collect to a final MessageResponse
/// let response = try await stream.collect()
///
/// // Or stream only text
/// for try await text in stream.textStream { print(text, terminator: "") }
/// ```
public struct MessageStream: AsyncSequence, Sendable {
    public typealias Element = MessageStreamEvent

    private let dataStream: AsyncThrowingStream<Data, Error>

    init(dataStream: AsyncThrowingStream<Data, Error>) {
        self.dataStream = dataStream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sseStream: SSEParser.parse(dataStream))
    }

    // MARK: - AsyncIterator

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var sseStream: AsyncThrowingStream<SSEParser.RawSSEEvent, Error>.AsyncIterator

        init(sseStream: AsyncThrowingStream<SSEParser.RawSSEEvent, Error>) {
            self.sseStream = sseStream.makeAsyncIterator()
        }

        public mutating func next() async throws -> MessageStreamEvent? {
            guard let raw = try await sseStream.next() else { return nil }
            return try decode(raw)
        }

        private func decode(_ raw: SSEParser.RawSSEEvent) throws -> MessageStreamEvent {
            // Terminal sentinel
            if raw.data == "[DONE]" { return .messageStop }

            guard let jsonData = raw.data.data(using: .utf8) else {
                throw AnthropicError.streamParseError("Could not convert SSE data to UTF-8: \(raw.data)")
            }

            let eventType = raw.eventType ?? ""

            do {
                switch eventType {
                case "message_start":
                    let event = try JSONCoding.decoder.decode(MessageStartEvent.self, from: jsonData)
                    return .messageStart(event)
                case "message_delta":
                    let event = try JSONCoding.decoder.decode(MessageDeltaEvent.self, from: jsonData)
                    return .messageDelta(event)
                case "message_stop":
                    return .messageStop
                case "content_block_start":
                    let event = try JSONCoding.decoder.decode(ContentBlockStartEvent.self, from: jsonData)
                    return .contentBlockStart(event)
                case "content_block_delta":
                    let event = try JSONCoding.decoder.decode(ContentBlockDeltaEvent.self, from: jsonData)
                    return .contentBlockDelta(event)
                case "content_block_stop":
                    let event = try JSONCoding.decoder.decode(ContentBlockStopEvent.self, from: jsonData)
                    return .contentBlockStop(index: event.index)
                case "ping":
                    return .ping
                case "error":
                    let event = try JSONCoding.decoder.decode(StreamErrorEvent.self, from: jsonData)
                    throw AnthropicError.apiError(APIError(type: "error", error: .init(type: event.error.type, message: event.error.message)))
                default:
                    return .unknown(type: eventType)
                }
            } catch let error as AnthropicError {
                throw error
            } catch let error as DecodingError {
                throw AnthropicError.decodingError(error, rawBody: jsonData)
            }
        }
    }
}
