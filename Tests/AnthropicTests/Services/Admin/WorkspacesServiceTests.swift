import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class WorkspacesServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    func testListWorkspaces() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/workspaces")
            return HTTPResponse(statusCode: 200, body: MockResponses.workspaceList)
        }
        let page = try await client.admin.workspaces.list()
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].name, "My Workspace")
    }

    func testCreateWorkspace() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.path, "/v1/organizations/workspaces")
            return HTTPResponse(statusCode: 200, body: MockResponses.workspace)
        }
        let workspace = try await client.admin.workspaces.create(CreateWorkspaceRequest(name: "New WS"))
        XCTAssertEqual(workspace.id, "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
    }

    func testGetWorkspace() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.path, "/v1/organizations/workspaces/wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
            return HTTPResponse(statusCode: 200, body: MockResponses.workspace)
        }
        let workspace = try await client.admin.workspaces.get(id: "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
        XCTAssertEqual(workspace.name, "My Workspace")
    }

    func testArchiveWorkspace() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.method, "POST")
            XCTAssertTrue(request.path.hasSuffix("/archive"))
            return HTTPResponse(statusCode: 200, body: MockResponses.workspace)
        }
        _ = try await client.admin.workspaces.archive(id: "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ")
    }
}
