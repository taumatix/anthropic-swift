import Foundation

/// A request to count the tokens in a message without sending it.
public struct CountTokensRequest: Sendable, Encodable {
    public var model: Model
    public var messages: [MessageParam]
    public var system: SystemPrompt?
    public var tools: [Tool]?

    public init(
        model: Model,
        messages: [MessageParam],
        system: SystemPrompt? = nil,
        tools: [Tool]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.system = system
        self.tools = tools
    }
}
