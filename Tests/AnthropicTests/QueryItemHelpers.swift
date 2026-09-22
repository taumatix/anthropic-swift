import Foundation
@testable import Anthropic

extension Collection where Element == URLQueryItem {
    /// Query values keyed by name, dropping items without a value and letting the last value win
    /// on a repeated name.
    ///
    /// `Dictionary(uniqueKeysWithValues:)` traps on a repeat rather than failing a test, and
    /// repeated names are a real shape — the Files GA surface uses `ids[]`.
    var queryValuesByName: [String: String] {
        Dictionary(compactMap { item in item.value.map { (item.name, $0) } },
                   uniquingKeysWith: { _, last in last })
    }
}

extension HTTPRequest {
    /// Query parameters keyed by name. See ``Swift/Collection/queryValuesByName``.
    var queryItemsByName: [String: String] { queryItems.queryValuesByName }
}
