import Foundation

/// A pure SSE (Server-Sent Events) line parser with no HTTP dependencies.
///
/// Accepts a stream of `Data` chunks (one line per chunk from `URLSession.bytes`)
/// and produces `RawSSEEvent` values — one per blank-line-delimited event block.
///
/// This type is independently unit-testable without any HTTP infrastructure.
struct SSEParser {
    /// A raw SSE event before JSON decoding.
    struct RawSSEEvent: Sendable {
        let eventType: String?
        let data: String
    }

    /// Parses a stream of `Data` line-chunks into `RawSSEEvent` values.
    static func parse(_ lineStream: AsyncThrowingStream<Data, Error>) -> AsyncThrowingStream<RawSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var currentEventType: String? = nil
                var dataLines: [String] = []

                do {
                    for try await lineData in lineStream {
                        guard let line = String(data: lineData, encoding: .utf8) else { continue }
                        // Strip leading/trailing whitespace and line endings (SSE spec allows leading spaces)
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                        if trimmed.isEmpty {
                            // Blank line = dispatch event
                            if !dataLines.isEmpty {
                                let data = dataLines.joined(separator: "\n")
                                continuation.yield(RawSSEEvent(eventType: currentEventType, data: data))
                            }
                            currentEventType = nil
                            dataLines = []
                        } else if trimmed.hasPrefix(":") {
                            // Comment / keep-alive — ignore
                            continue
                        } else if trimmed.hasPrefix("event:") {
                            currentEventType = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if trimmed.hasPrefix("data:") {
                            let value = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataLines.append(value)
                        }
                        // Ignore id: and retry: fields
                    }
                    // Handle any trailing event without a final blank line
                    if !dataLines.isEmpty {
                        let data = dataLines.joined(separator: "\n")
                        continuation.yield(RawSSEEvent(eventType: currentEventType, data: data))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
