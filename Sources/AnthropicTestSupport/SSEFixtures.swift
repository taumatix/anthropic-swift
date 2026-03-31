import Foundation

/// Canned SSE (Server-Sent Events) byte sequences for streaming tests.
public enum SSEFixtures {
    /// A complete non-streaming message as an SSE stream.
    public static let basicMessageStream: Data = {
        let events = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_01XFDUDYJgAACzvnptvVoYEL","type":"message","role":"assistant","content":[],"model":"claude-opus-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: ping
        data: {"type":"ping"}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"!"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":2}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        return Data(events.utf8)
    }()

    /// SSE stream containing a tool_use block.
    public static let toolUseStream: Data = {
        let events = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_tooluse","type":"message","role":"assistant","content":[],"model":"claude-opus-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":68,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01A09q90qw90lq917835lq9","name":"get_weather","input":{}}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\\"location\\\":"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"\\\"SF\\\"}"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":14}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        return Data(events.utf8)
    }()

    /// SSE stream that contains an error event mid-stream.
    public static let errorStream: Data = {
        let events = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_err","type":"message","role":"assistant","content":[],"model":"claude-opus-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}}}

        event: error
        data: {"type":"error","error":{"type":"api_error","message":"Internal server error"}}

        """
        return Data(events.utf8)
    }()

    /// Helper that converts `Data` to a `AsyncThrowingStream<Data, Error>` yielding line by line.
    public static func lineStream(from data: Data) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            var lineBuffer = Data()
            for byte in data {
                lineBuffer.append(byte)
                if byte == UInt8(ascii: "\n") {
                    continuation.yield(lineBuffer)
                    lineBuffer = Data()
                }
            }
            if !lineBuffer.isEmpty {
                continuation.yield(lineBuffer)
            }
            continuation.finish()
        }
    }
}
