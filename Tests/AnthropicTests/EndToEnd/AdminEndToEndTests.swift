#if canImport(Network)
import XCTest
import Anthropic
import AnthropicTestSupport

/// End-to-end tests for the Admin API over a real TCP socket, replaying the response bodies
/// Anthropic publishes (retrieved 2026-10-09). Not covered: that Anthropic still serves these
/// bodies, and the list endpoints, whose bodies are assumed to share the retrieve shape.
final class AdminEndToEndTests: XCTestCase {

    private var server: LoopbackHTTPServer!

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    func testMembersInvitesWorkspacesAndKeysUseThePublishedRoutesAndBodies() async throws {
        let server = try LoopbackHTTPServer { request in
            switch (request.method, request.path) {
            case ("GET", "/v1/organizations/users/user_01WCz1FkmYMm4gnmykNKUu3Q"),
                 ("POST", "/v1/organizations/users/user_01WCz1FkmYMm4gnmykNKUu3Q"):
                return .json(200, MockResponses.memberVendor)
            case ("DELETE", "/v1/organizations/users/user_01WCz1FkmYMm4gnmykNKUu3Q"):
                return .json(200, MockResponses.memberDeletedVendor)
            case ("GET", "/v1/organizations/invites/invite_015gWxCN9Hfg2QhZwTK7Mdeu"):
                return .json(200, MockResponses.inviteVendor)
            case ("DELETE", "/v1/organizations/invites/invite_015gWxCN9Hfg2QhZwTK7Mdeu"):
                return .json(200, MockResponses.inviteDeletedVendor)
            case ("GET", "/v1/organizations/workspaces/wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ"),
                 ("POST", "/v1/organizations/workspaces/wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ/archive"):
                return .json(200, MockResponses.workspaceVendor)
            case ("GET", "/v1/organizations/api_keys/apikey_01Rj2N8SVvo6BePZj99NhmiT"):
                return .json(200, MockResponses.apiKeyVendor)
            default:
                return .json(404, Data(#"{"type":"error","error":{"type":"not_found_error","message":"Not found"}}"#.utf8))
            }
        }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))

        let updated = try await client.admin.members.update(
            userId: "user_01WCz1FkmYMm4gnmykNKUu3Q",
            request: UpdateMemberRequest(organizationRole: .developer))
        XCTAssertEqual(updated.userId, "user_01WCz1FkmYMm4gnmykNKUu3Q")
        try await client.admin.members.delete(userId: "user_01WCz1FkmYMm4gnmykNKUu3Q")

        let invite = try await client.admin.invites.get(id: "invite_015gWxCN9Hfg2QhZwTK7Mdeu")
        XCTAssertEqual(invite.rbacGroupIds, ["string"])
        let gone = try await client.admin.invites.delete(id: "invite_015gWxCN9Hfg2QhZwTK7Mdeu")
        XCTAssertTrue(gone.deleted)

        let ws = try await client.admin.workspaces.get(id: "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
        XCTAssertEqual(ws.tags?["team"], "platform")
        let archived = try await client.admin.workspaces.archive(id: "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
        XCTAssertEqual(archived, ws)

        let key = try await client.admin.apiKeys.get(id: "apikey_01Rj2N8SVvo6BePZj99NhmiT")
        XCTAssertEqual(key.scope?.type, "workspace")

        let seen = server.receivedRequests.map { "\($0.method) \($0.path)" }
        XCTAssertEqual(seen.first, "POST /v1/organizations/users/user_01WCz1FkmYMm4gnmykNKUu3Q")
        XCTAssertEqual(seen.count, 7)
    }

    func testWorkspaceListCarriesItsFiltersAcrossPagesOverARealSocket() async throws {
        let first = String(decoding: MockResponses.workspaceVendor, as: UTF8.self)
        let page1 = Data("""
        {"data":[\(first)],"first_id":"wrkspc_a","has_more":true,"last_id":"wrkspc_a"}
        """.utf8)
        let page2 = Data(#"{"data":[],"first_id":null,"has_more":false,"last_id":null}"#.utf8)
        let server = try LoopbackHTTPServer { request in
            .json(200, request.query["after_id"] == nil ? page1 : page2)
        }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))

        var count = 0
        for try await _ in try await client.admin.workspaces.list(
            limit: 1, includeArchived: true, includeDefault: false) { count += 1 }
        XCTAssertEqual(count, 1)

        let requests = server.receivedRequests
        XCTAssertEqual(requests.count, 2)
        for r in requests {
            XCTAssertEqual(r.query["include_archived"], "true")
            XCTAssertEqual(r.query["include_default"], "false")
            XCTAssertEqual(r.query["limit"], "1")
        }
        XCTAssertEqual(requests[1].query["after_id"], "wrkspc_a")
    }

    func testMemberInviteAndKeyListsCarryTheirFiltersAcrossPagesOverARealSocket() async throws {
        let page1 = Data(#"{"data":[],"first_id":"x","has_more":true,"last_id":"x"}"#.utf8)
        let page2 = Data(#"{"data":[],"first_id":null,"has_more":false,"last_id":null}"#.utf8)
        let server = try LoopbackHTTPServer { request in
            .json(200, request.query["after_id"] == nil ? page1 : page2)
        }
        self.server = server
        let baseURL = try await server.start()
        let client = AnthropicClient(
            apiKey: "test-key",
            options: ClientOptions(apiKey: "test-key").baseURL(baseURL).maxRetries(0))

        for try await _ in try await client.admin.members.list(
            limit: 1, email: "a@b.co", roles: ["admin", "billing"]) {}
        for try await _ in try await client.admin.invites.list(
            limit: 1, email: "a@b.co", roles: ["user"], statuses: ["pending", "expired"]) {}
        for try await _ in try await client.admin.apiKeys.list(
            limit: 1, status: "active", workspaceId: "wrkspc_1", createdByUserId: "user_1") {}

        let requests = server.receivedRequests
        XCTAssertEqual(requests.count, 6)
        for r in requests[0...1] {
            XCTAssertTrue(r.target.hasPrefix("/v1/organizations/users?"))
            XCTAssertEqual(r.query["email"], "a@b.co")
            XCTAssertTrue(r.target.contains("roles=admin&roles=billing"), r.target)
        }
        for r in requests[2...3] {
            XCTAssertTrue(r.target.hasPrefix("/v1/organizations/invites?"))
            XCTAssertTrue(r.target.contains("statuses=pending&statuses=expired"), r.target)
            XCTAssertEqual(r.query["roles"], "user")
        }
        for r in requests[4...5] {
            XCTAssertTrue(r.target.hasPrefix("/v1/organizations/api_keys?"))
            XCTAssertEqual(r.query["status"], "active")
            XCTAssertEqual(r.query["workspace_id"], "wrkspc_1")
            XCTAssertEqual(r.query["created_by_user_id"], "user_1")
        }
        for i in [1, 3, 5] { XCTAssertEqual(requests[i].query["after_id"], "x") }
        for i in [0, 2, 4] { XCTAssertEqual(requests[i].query["limit"], "1") }
    }
}
#endif
