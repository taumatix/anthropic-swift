import XCTest
@testable import Anthropic
import AnthropicTestSupport

final class SkillsServiceTests: XCTestCase {
    var mock: MockHTTPClient!
    var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        client = AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", httpClient: mock))
    }

    let skillJSON = Data("""
    {"id":"skill_01","type":"skill","name":"My Skill","description":"A skill","created_at":"2025-01-01"}
    """.utf8)

    func testCreateSkillSendsBetaHeader() async throws {
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "skills-2025-10-02")
            XCTAssertEqual(request.method, "POST")
            return HTTPResponse(statusCode: 200, body: self.skillJSON)
        }
        let skill = try await client.skills.create(CreateSkillRequest(name: "My Skill"))
        XCTAssertEqual(skill.name, "My Skill")
    }

    func testListSkillsSendsBetaHeader() async throws {
        let listJSON = Data("""
        {"data":[{"id":"skill_01","type":"skill","name":"My Skill","description":null,"created_at":"2025-01-01"}],"has_more":false,"first_id":"skill_01","last_id":"skill_01"}
        """.utf8)
        mock.handler = { request in
            XCTAssertEqual(request.headers["anthropic-beta"], "skills-2025-10-02")
            return HTTPResponse(statusCode: 200, body: listJSON)
        }
        let page = try await client.skills.list()
        XCTAssertEqual(page.data.count, 1)
    }
}
