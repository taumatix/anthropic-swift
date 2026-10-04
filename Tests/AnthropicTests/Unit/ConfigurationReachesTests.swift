import XCTest
import Anthropic
import AnthropicTestSupport

/// Every setting on `ClientConfiguration` must change something a caller can observe.
///
/// `baseURL` (2026-09-22) and `timeout` (0.8.0) were both stored and read by nothing, for months,
/// with a green suite. Each setting has one check here, and `testEverySettingHasACheck` lists the
/// struct's stored properties by reflection, so a setting added without a check fails the suite
/// instead of shipping dead.
final class ConfigurationReachesTests: XCTestCase {

    private static let fastRetries = RetryPolicy(
        strategy: .exponentialBackoff(base: 0, multiplier: 1, maxDelay: 0),
        retryableStatusCodes: [529]
    )

    /// One configuration, a mock that answers, and what the mock was sent.
    private func send(
        _ configure: (inout ClientConfiguration) -> Void,
        status: Int = 200,
        admin: Bool = false
    ) async -> (requests: [HTTPRequest], error: Error?) {
        let mock = MockHTTPClient()
        mock.handler = { _ in
            HTTPResponse(statusCode: status, body: admin ? MockResponses.workspaceList : MockResponses.singleMessage)
        }
        var configuration = ClientConfiguration(apiKey: "key-from-test", httpClient: mock)
        configure(&configuration)
        let client = AnthropicClient(configuration: configuration)
        do {
            if admin {
                _ = try await client.admin.workspaces.list()
            } else {
                _ = try await client.messages.create(MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 8))
            }
            return (mock.recordedRequests, nil)
        } catch {
            return (mock.recordedRequests, error)
        }
    }

    /// The check for each stored property, by the name reflection reports.
    private var checks: [String: () async throws -> Void] {
        [
            "apiKey": {
                let sent = await self.send { $0.apiKey = "sk-changed" }
                XCTAssertEqual(sent.requests.first?.headers["x-api-key"], "sk-changed")
            },
            "adminAPIKey": {
                let sent = await self.send({ $0.adminAPIKey = "sk-admin" }, admin: true)
                XCTAssertNil(sent.error)
                XCTAssertEqual(sent.requests.first?.headers["x-api-key"], "sk-admin")
            },
            "baseURL": {
                // A plaintext, non-loopback base URL is refused before the client is called, which
                // is only possible if the configured value is read.
                let sent = await self.send { $0.baseURL = URL(string: "http://gateway.internal.example")! }
                XCTAssertNotNil(sent.error)
                XCTAssertTrue(sent.requests.isEmpty)
            },
            "allowsInsecureBaseURL": {
                let sent = await self.send {
                    $0.baseURL = URL(string: "http://gateway.internal.example")!
                    $0.allowsInsecureBaseURL = true
                }
                XCTAssertNil(sent.error)
                XCTAssertEqual(sent.requests.count, 1)
            },
            "anthropicVersion": {
                let sent = await self.send { $0.anthropicVersion = "2099-01-01" }
                XCTAssertEqual(sent.requests.first?.headers["anthropic-version"], "2099-01-01")
            },
            "timeout": {
                let sent = await self.send { $0.timeout = 7 }
                XCTAssertEqual(sent.requests.first?.timeout, 7)
            },
            "maxRetries": {
                let sent = await self.send({
                    $0.retryPolicy = Self.fastRetries
                    $0.maxRetries = 3
                }, status: 529)
                XCTAssertEqual(sent.requests.count, 4, "one attempt and three retries")
            },
            "retryPolicy": {
                let sent = await self.send({
                    $0.retryPolicy = RetryPolicy(strategy: .none, retryableStatusCodes: [])
                    $0.maxRetries = 3
                }, status: 529)
                XCTAssertEqual(sent.requests.count, 1, "a policy retrying nothing still retried")
            },
            "additionalHeaders": {
                let sent = await self.send { $0.additionalHeaders = ["x-request-id": "abc"] }
                XCTAssertEqual(sent.requests.first?.headers["x-request-id"], "abc")
            },
            "storedHTTPClient": {
                // Behind the public httpClient: the request goes to the client configured.
                let other = MockHTTPClient()
                other.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
                _ = await self.send { $0.httpClient = other }
                XCTAssertEqual(other.recordedRequests.count, 1)
            },
        ]
    }

    func testEverySettingHasACheck() {
        let configuration = ClientConfiguration(apiKey: "k")
        let stored = Set(Mirror(reflecting: configuration).children.compactMap(\.label))
        let checked = Set(checks.keys)
        XCTAssertEqual(stored.subtracting(checked).sorted(), [],
                       "ClientConfiguration properties with no check here: add one that shows each reaches a request")
        XCTAssertEqual(checked.subtracting(stored).sorted(), [],
                       "checks for properties ClientConfiguration no longer has")
    }

    func testEverySettingReachesARequest() async throws {
        for (name, check) in checks.sorted(by: { $0.key < $1.key }) {
            XCTContext.runActivity(named: name) { _ in }
            try await check()
        }
    }
}
