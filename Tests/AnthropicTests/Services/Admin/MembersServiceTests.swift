import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class MembersServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testListMembers() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/members")
            return HTTPResponse(statusCode: 200, body: MockResponses.memberList)
        }
        let page = try await client.admin.members.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].email, "user@example.com")
    }

    func testUpdateMember() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "PATCH")
            XCTAssertEqual(request.path, "/v1/organizations/members/user_01WCz1FkmYMm4gnmykNKvp7Y")
            return HTTPResponse(statusCode: 200, body: MockResponses.member)
        }
        let updated = try await client.admin.members.update(
            userId: "user_01WCz1FkmYMm4gnmykNKvp7Y",
            request: UpdateMemberRequest(organizationRole: .admin)
        )
        XCTAssertEqual(updated.organizationRole, .user) // fixture returns "user"
    }

    func testDeleteMember() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            XCTAssertEqual(request.path, "/v1/organizations/members/user_01WCz1FkmYMm4gnmykNKvp7Y")
            return HTTPResponse(statusCode: 200, body: Data("{}".utf8))
        }
        try await client.admin.members.delete(userId: "user_01WCz1FkmYMm4gnmykNKvp7Y")
    }
}
