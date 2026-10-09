import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class AdminWireShapeTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try JSONCoding.decoder.decode(type, from: data)
    }

    func testWorkspaceDecodesTheDocumentedBody() throws {
        let ws = try decode(Workspace.self, MockResponses.workspaceVendor)
        XCTAssertEqual(ws.compartmentId, "f8a7b6c5-4d3e-4f1a-8b9c-0d1e2f3a4b5c")
        XCTAssertEqual(ws.externalKeyId, "ekey_01SDCCSbTxrXDpWc1phhtcfK")
        XCTAssertEqual(ws.tags, ["env": "prod", "team": "platform"])
        XCTAssertEqual(ws.dataResidency?.allowsAllInferenceGeos, true)
        XCTAssertNil(ws.dataResidency?.allowedInferenceGeos)
        XCTAssertEqual(ws.dataResidency?.defaultInferenceGeo, "global")
        XCTAssertEqual(ws.dataResidency?.workspaceGeo, "us")
    }

    func testWorkspaceDataResidencyAcceptsAListOfGeos() throws {
        let body = Data(#"{"allowed_inference_geos":["us"],"default_inference_geo":"us","workspace_geo":"us"}"#.utf8)
        let r = try decode(WorkspaceDataResidency.self, body)
        XCTAssertEqual(r.allowedInferenceGeos, ["us"])
        XCTAssertFalse(r.allowsAllInferenceGeos)
    }

    func testAPIKeyDecodesTheDocumentedBody() throws {
        let key = try decode(OrganizationAPIKey.self, MockResponses.apiKeyVendor)
        XCTAssertEqual(key.partialKeyHint, "sk-ant-api03-R2D...igAA")
        XCTAssertEqual(key.principal?.type, "user_actor")
        XCTAssertEqual(key.principal?.userId, "user_01WCz1FkmYMm4gnmykNKUu3Q")
        XCTAssertEqual(key.scope?.workspaceId, "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
        XCTAssertNotNil(key.expiresAt)
        XCTAssertNil(key.lastUsedAt)
    }

    func testAPIKeyStatusesArchivedAndExpiredExist() {
        XCTAssertEqual(APIKeyStatus.archived.rawValue, "archived")
        XCTAssertEqual(APIKeyStatus.expired.rawValue, "expired")
    }

    func testInviteDecodesTheDocumentedBody() throws {
        let invite = try decode(OrganizationInvite.self, MockResponses.inviteVendor)
        XCTAssertEqual(invite.acceptedAt, "2019-12-27T18:11:19.117Z")
        XCTAssertEqual(invite.rbacGroupIds, ["string"])
        XCTAssertEqual(invite.role, .admin)
    }

    func testInviteDeleteResponseDecodesWithoutADeletedKey() throws {
        let r = try decode(InviteDeleteResponse.self, MockResponses.inviteDeletedVendor)
        XCTAssertEqual(r.type, "invite_deleted")
        XCTAssertTrue(r.deleted)
    }

    func testMemberDecodesTheDocumentedBodyAndTheOldNames() throws {
        let m = try decode(OrganizationMember.self, MockResponses.memberVendor)
        XCTAssertEqual(m.userId, "user_01WCz1FkmYMm4gnmykNKUu3Q")
        XCTAssertEqual(m.organizationRole, .admin)
        let old = try decode(OrganizationMember.self, MockResponses.member)
        XCTAssertEqual(old.userId, "user_01WCz1FkmYMm4gnmykNKvp7Y")
        XCTAssertEqual(old.organizationRole, .user)
    }

    func testUpdateMemberRequestSendsRole() throws {
        let data = try JSONCoding.encoder.encode(UpdateMemberRequest(organizationRole: .developer))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"role":"developer"}"#)
    }

    func testCreateRequestsOmitUnsetOptionalFields() throws {
        let ws = try JSONCoding.encoder.encode(CreateWorkspaceRequest(name: "x"))
        XCTAssertEqual(String(decoding: ws, as: UTF8.self), #"{"name":"x"}"#)
        let ws2 = try JSONCoding.encoder.encode(CreateWorkspaceRequest(name: "x", displayColor: "#6C5BB9", tags: ["a": "b"]))
        XCTAssertEqual(String(decoding: ws2, as: UTF8.self), ##"{"display_color":"#6C5BB9","name":"x","tags":{"a":"b"}}"##)
        let inv = try JSONCoding.encoder.encode(CreateInviteRequest(email: "a@b.c", role: .user))
        XCTAssertEqual(String(decoding: inv, as: UTF8.self), #"{"email":"a@b.c","role":"user"}"#)
    }

    func testIdsArePercentEncodedInPaths() async throws {
        let mock = MockHTTPClient()
        let client = AnthropicClient(configuration: ClientConfiguration(apiKey: "k", httpClient: mock))
        var paths: [String] = []
        mock.handler = { request in
            paths.append(request.path)
            return HTTPResponse(statusCode: 200, body: Data("{}".utf8))
        }
        _ = try? await client.admin.apiKeys.get(id: "../x")
        _ = try? await client.admin.invites.get(id: "../x")
        _ = try? await client.admin.invites.delete(id: "../x")
        _ = try? await client.admin.workspaces.get(id: "../x")
        _ = try? await client.admin.workspaces.archive(id: "../x")
        try? await client.admin.members.delete(userId: "../x")
        _ = try? await client.admin.members.update(userId: "../x", request: UpdateMemberRequest(organizationRole: .user))
        XCTAssertEqual(paths.count, 7)
        for path in paths {
            XCTAssertFalse(path.contains("/../"), path)
            XCTAssertTrue(path.contains("..%2Fx"), path)
        }
    }
}
