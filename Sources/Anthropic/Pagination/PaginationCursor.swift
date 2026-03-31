import Foundation

/// Cursor position for paginated list requests.
public struct PaginationCursor: Sendable {
    /// Return results after this ID.
    public let afterId: String?
    /// Return results before this ID.
    public let beforeId: String?

    public static let initial = PaginationCursor(afterId: nil, beforeId: nil)

    public init(afterId: String? = nil, beforeId: String? = nil) {
        self.afterId = afterId
        self.beforeId = beforeId
    }

    /// Converts to `URLQueryItem` array for use in requests.
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let afterId = afterId { items.append(URLQueryItem(name: "after_id", value: afterId)) }
        if let beforeId = beforeId { items.append(URLQueryItem(name: "before_id", value: beforeId)) }
        return items
    }
}
