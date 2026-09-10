import Foundation

/// Identifies a Claude model.
///
/// Use the named constants for known models, or provide any string for custom/future models:
/// ```swift
/// let request = MessageRequest(model: .claudeSonnet5, ...)
/// let request = MessageRequest(model: "claude-opus-5", ...)
/// ```
///
/// Anthropic adds and retires models faster than this SDK releases, so the constants below are a
/// convenience, not the source of truth. A model ID this SDK has never heard of works fine as a
/// string literal, and ``ModelsService/list()`` returns what the API currently serves.
public struct Model: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }

    // MARK: - Current models
    //
    // These follow the wire IDs, which changed shape with the Claude 4.6 generation:
    // tier-then-version (`claude-opus-5`) rather than the older family-then-tier
    // (`claude-3-5-sonnet`). The constant names mirror that, so `claudeOpus5` here and
    // `claude35Sonnet` below are both named after the ID they carry.

    /// Claude Fable 5 — the most capable widely released model, for the most demanding reasoning
    /// and long-horizon agentic work. Requires 30-day data retention; not available under ZDR.
    public static let claudeFable5 = Model(rawValue: "claude-fable-5")

    /// Claude Mythos 5 — same capabilities and pricing as ``claudeFable5``, available only to
    /// Project Glasswing participants. Use ``claudeFable5`` unless your organization takes part.
    public static let claudeMythos5 = Model(rawValue: "claude-mythos-5")

    /// Claude Opus 5 — the current Opus, for complex agentic coding and enterprise work.
    public static let claudeOpus5 = Model(rawValue: "claude-opus-5")

    /// Claude Opus 4.8 — the previous Opus generation.
    public static let claudeOpus48 = Model(rawValue: "claude-opus-4-8")

    /// Claude Opus 4.7.
    public static let claudeOpus47 = Model(rawValue: "claude-opus-4-7")

    /// Claude Opus 4.6.
    public static let claudeOpus46 = Model(rawValue: "claude-opus-4-6")

    /// Claude Opus 4.5.
    public static let claudeOpus45 = Model(rawValue: "claude-opus-4-5")

    /// Claude Sonnet 5 — the best balance of speed and intelligence in the Sonnet tier.
    public static let claudeSonnet5 = Model(rawValue: "claude-sonnet-5")

    /// Claude Sonnet 4.6 — the previous Sonnet generation.
    public static let claudeSonnet46 = Model(rawValue: "claude-sonnet-4-6")

    /// Claude Sonnet 4.5.
    public static let claudeSonnet45 = Model(rawValue: "claude-sonnet-4-5")

    /// Claude Haiku 4.5 — the fastest and most cost-effective model.
    public static let claudeHaiku45 = Model(rawValue: "claude-haiku-4-5")

    // MARK: - Claude 4 family (retained for source compatibility)
    //
    // These names were pinned to the 4.5 generation when they were introduced and keep those
    // values — repointing them at a newer model would silently change the model a caller runs
    // against. Prefer the explicitly versioned constants above.

    /// The Opus model of the Claude 4 generation, pinned to Opus 4.5.
    ///
    /// Equivalent to ``claudeOpus45``. Prefer ``claudeOpus5`` for new code.
    public static let claude4Opus = Model(rawValue: "claude-opus-4-5")

    /// The Sonnet model of the Claude 4 generation, pinned to Sonnet 4.5.
    ///
    /// Equivalent to ``claudeSonnet45``. Prefer ``claudeSonnet5`` for new code.
    public static let claude4Sonnet = Model(rawValue: "claude-sonnet-4-5")

    /// The Haiku model of the Claude 4 generation, pinned to the dated Haiku 4.5 snapshot.
    ///
    /// Resolves to the same model as ``claudeHaiku45``.
    public static let claude4Haiku = Model(rawValue: "claude-haiku-4-5-20251001")

    // MARK: - Retired and deprecated models
    //
    // The API returns 404 for a retired model. These constants stay so existing code keeps
    // compiling, but every one of them fails at runtime — hence the deprecation warnings.

    @available(*, deprecated, message: "Retired 2026-02-19; the API returns 404. Use .claudeSonnet5.")
    public static let claude37Sonnet = Model(rawValue: "claude-3-7-sonnet-20250219")

    @available(*, deprecated, message: "Retired 2025-10-28; the API returns 404. Use .claudeSonnet5.")
    public static let claude35Sonnet = Model(rawValue: "claude-3-5-sonnet-20241022")

    @available(*, deprecated, message: "Retired 2025-10-28; the API returns 404. Use .claudeSonnet5.")
    public static let claude35SonnetLatest = Model(rawValue: "claude-3-5-sonnet-latest")

    @available(*, deprecated, message: "Retired 2026-02-19; the API returns 404. Use .claudeHaiku45.")
    public static let claude35Haiku = Model(rawValue: "claude-3-5-haiku-20241022")

    @available(*, deprecated, message: "Retired 2026-02-19; the API returns 404. Use .claudeHaiku45.")
    public static let claude35HaikuLatest = Model(rawValue: "claude-3-5-haiku-latest")

    @available(*, deprecated, message: "Retired 2026-01-05; the API returns 404. Use .claudeOpus5.")
    public static let claude3Opus = Model(rawValue: "claude-3-opus-20240229")

    @available(*, deprecated, message: "Retired 2025-07-21; the API returns 404. Use .claudeSonnet5.")
    public static let claude3Sonnet = Model(rawValue: "claude-3-sonnet-20240229")

    @available(*, deprecated, message: "Deprecated; retires 2026-04-19. Use .claudeHaiku45.")
    public static let claude3Haiku = Model(rawValue: "claude-3-haiku-20240307")
}
