import Foundation

/// Defines when and how requests should be retried.
public struct RetryPolicy: Sendable {
    /// The backoff strategy to use between retry attempts.
    public enum Strategy: Sendable {
        /// No retries are performed.
        case none
        /// Exponential backoff: delay = min(base * multiplier^attempt, maxDelay).
        case exponentialBackoff(base: TimeInterval, multiplier: Double, maxDelay: TimeInterval)
    }

    /// The backoff strategy. Default: exponential backoff starting at 0.5s, capped at 30s.
    public var strategy: Strategy
    /// HTTP status codes that trigger a retry. Default: 429, 500, 502, 503, 529.
    public var retryableStatusCodes: Set<Int>

    public static let `default` = RetryPolicy(
        strategy: .exponentialBackoff(base: 0.5, multiplier: 2.0, maxDelay: 30.0),
        retryableStatusCodes: [429, 500, 502, 503, 529]
    )

    public init(strategy: Strategy, retryableStatusCodes: Set<Int>) {
        self.strategy = strategy
        self.retryableStatusCodes = retryableStatusCodes
    }

    /// Returns `true` if the response should trigger a retry.
    func shouldRetry(response: HTTPResponse, attempt: Int, maxRetries: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        return retryableStatusCodes.contains(response.statusCode)
    }

    /// Returns the delay (in seconds) before the next retry attempt.
    /// For 429 responses, uses the `Retry-After` header if present.
    func delay(for response: HTTPResponse, attempt: Int) -> TimeInterval {
        // Honour server-specified Retry-After for 429
        if response.statusCode == 429, let retryAfter = response.retryAfter {
            return retryAfter
        }
        switch strategy {
        case .none:
            return 0
        case .exponentialBackoff(let base, let multiplier, let maxDelay):
            let delay = base * pow(multiplier, Double(attempt))
            return min(delay, maxDelay)
        }
    }
}
