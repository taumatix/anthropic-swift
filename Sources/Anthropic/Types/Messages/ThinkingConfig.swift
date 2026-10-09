import Foundation

/// Whether, and how, the model reasons before it answers (the `thinking` request parameter).
///
/// ```swift
/// let request = MessageRequest(
///     model: .claudeSonnet55, messages: [.user("Plan a route")], maxTokens: 4096,
///     thinking: .enabled(budgetTokens: 2048))
/// ```
///
/// Shapes are from the Messages reference (retrieved 2026-10-09). Which models accept which
/// form is not checked here: the API rejects an unsupported one.
public enum ThinkingConfig: Sendable, Encodable, Equatable {
    /// How thinking content is returned. `omitted` redacts the text but keeps the signature a
    /// later turn needs.
    public enum Display: String, Sendable, Encodable, Equatable {
        case summarized
        case omitted
    }

    /// Reason with a fixed token budget (at least 1024, below `maxTokens`).
    case enabled(budgetTokens: Int, display: Display? = nil)
    /// No reasoning.
    case disabled
    /// The model decides whether and how much to reason.
    case adaptive(display: Display? = nil)
    /// Reason between tool calls.
    case betweenTools

    private enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
        case display
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .enabled(let budget, let display):
            try c.encode("enabled", forKey: .type)
            try c.encode(budget, forKey: .budgetTokens)
            try c.encodeIfPresent(display, forKey: .display)
        case .disabled:
            try c.encode("disabled", forKey: .type)
        case .adaptive(let display):
            try c.encode("adaptive", forKey: .type)
            try c.encodeIfPresent(display, forKey: .display)
        case .betweenTools:
            try c.encode("between_tools", forKey: .type)
        }
    }
}
