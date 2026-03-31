import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class InvitesServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testListInvites() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/invites")
            return HTTPResponse(statusCode: 200, body: MockResponses.inviteList)
        }
        let page = try await client.admin.invites.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].email, "newuser@example.com")
    }

    func testCreateInvite() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/v1/organizations/invites")
            return HTTPResponse(statusCode: 200, body: MockResponses.invite)
        }
        let invite = try await client.admin.invites.create(
            CreateInviteRequest(email: "newuser@example.com", role: .user)
        )
        XCTAssertEqual(invite.email, "newuser@example.com")
        XCTAssertEqual(invite.status, .pending)
    }

    func testGetInvite() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/invites/invite_01J2qFhxxWVBDFMEcMFKNHha")
            return HTTPResponse(statusCode: 200, body: MockResponses.invite)
        }
        let invite = try await client.admin.invites.get(id: "invite_01J2qFhxxWVBDFMEcMFKNHha")
        XCTAssertEqual(invite.id, "invite_01J2qFhxxWVBDFMEcMFKNHha")
    }

    func testDeleteInvite() async throws {
        let deleteBody = Data(#"{"id":"invite_01J2qFhxxWVBDFMEcMFKNHha","type":"invite_deleted","deleted":true}"#.utf8)
        mock.handler = { request in
            XCTAssertEqual(request.method, "DELETE")
            return HTTPResponse(statusCode: 200, body: deleteBody)
        }
        let result = try await client.admin.invites.delete(id: "invite_01J2qFhxxWVBDFMEcMFKNHha")
        XCTAssertTrue(result.deleted)
    }
}
