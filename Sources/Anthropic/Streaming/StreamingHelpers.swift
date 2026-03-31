import Foundation

// MARK: - High-Level Streaming Conveniences

extension MessageStream {
    /// Accumulates all stream events and returns a final `MessageResponse`.
    ///
    /// Collects all content block deltas and assembles the complete response.
    /// Use this when you want streaming performance (time-to-first-token) but
    /// need the complete `MessageResponse` structure at the end.
    public func collect() async throws -> MessageResponse {
        var messageId = ""
        var role = "assistant"
        var model = Model(rawValue: "")
        var inputTokens = 0
        var outputTokens = 0
        var stopReason: StopReason? = nil
        var stopSequence: String? = nil

        // Per-block accumulators: index → (type, text, toolId, toolName, toolInputJSON)
        struct BlockAcc {
            var type: String = ""
            var text: String = ""
            var toolId: String = ""
            var toolName: String = ""
            var toolInputJSON: String = ""
        }
        var blocks: [Int: BlockAcc] = [:]

        for try await event in self {
            switch event {
            case .messageStart(let e):
                messageId = e.message.id
                role = e.message.role
                model = e.message.model
                inputTokens = e.message.usage.inputTokens

            case .contentBlockStart(let e):
                var acc = BlockAcc()
                switch e.contentBlock {
                case .text(let b): acc.type = "text"; acc.text = b.text
                case .toolUse(let b): acc.type = "tool_use"; acc.toolId = b.id; acc.toolName = b.name
                case .unknown: acc.type = "unknown"
                }
                blocks[e.index] = acc

            case .contentBlockDelta(let e):
                switch e.delta {
                case .textDelta(let text):
                    blocks[e.index, default: BlockAcc()].text += text
                case .inputJSONDelta(let partial):
                    blocks[e.index, default: BlockAcc()].toolInputJSON += partial
                case .unknown:
                    break
                }

            case .messageDelta(let e):
                stopReason = e.delta.stopReason
                stopSequence = e.delta.stopSequence
                outputTokens = e.usage.outputTokens

            case .messageStop, .ping, .unknown, .contentBlockStop:
                break
            case .error(let e):
                throw AnthropicError.apiError(
                    APIError(type: "error", error: .init(type: e.error.type, message: e.error.message))
                )
            }
        }

        // Assemble content blocks in order
        let sortedBlocks = blocks.sorted { $0.key < $1.key }
        let contentBlocks: [ContentBlock] = sortedBlocks.compactMap { _, acc in
            switch acc.type {
            case "text":
                return .text(.init(text: acc.text))
            case "tool_use":
                // Parse accumulated JSON input
                var input: [String: AnyJSONValue] = [:]
                if !acc.toolInputJSON.isEmpty,
                   let data = acc.toolInputJSON.data(using: .utf8),
                   let decoded = try? JSONCoding.decoder.decode([String: AnyJSONValue].self, from: data) {
                    input = decoded
                }
                return .toolUse(.init(id: acc.toolId, name: acc.toolName, input: input))
            default:
                return nil
            }
        }

        return MessageResponse(
            id: messageId,
            type: "message",
            role: role,
            content: contentBlocks,
            model: model,
            stopReason: stopReason,
            stopSequence: stopSequence,
            usage: Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        )
    }

    /// Returns a stream of text delta strings.
    ///
    /// Yields only the incremental text from `text_delta` events.
    /// Useful for real-time display of streaming responses:
    /// ```swift
    /// for try await text in client.messages.stream(request).textStream {
    ///     print(text, terminator: "")
    ///     fflush(stdout)
    /// }
    /// ```
    public var textStream: AsyncThrowingStream<String, Error> {
        let self_ = self
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in self_ {
                        if case .contentBlockDelta(let e) = event,
                           case .textDelta(let text) = e.delta {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
