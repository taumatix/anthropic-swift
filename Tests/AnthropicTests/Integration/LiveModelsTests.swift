import XCTest
import Anthropic

/// Models API against `api.anthropic.com`. Free: listing and reading models bills nothing.
final class LiveModelsTests: IntegrationTestCase {

    func testListDecodesEveryModelTheAPIReturns() async throws {
        let page = try await client.models.list(limit: 100)
        XCTAssertFalse(page.data.isEmpty, "the API listed no models")
        for model in page.data {
            XCTAssertEqual(model.type, "model", model.id)
            XCTAssertFalse(model.id.isEmpty)
            XCTAssertFalse(model.displayName.isEmpty, "\(model.id) has no display_name")
        }
    }

    func testGetReturnsWhatListReturned() async throws {
        let listed = try await client.models.list(limit: 1).data
        let first = try XCTUnwrap(listed.first)
        let fetched = try await client.models.get(id: first.id)
        XCTAssertEqual(fetched.id, first.id)
        XCTAssertEqual(fetched.displayName, first.displayName)
    }

    /// The constants this SDK calls current must be ones the API still serves. A failure names the
    /// constant to retire or re-date; it is the mechanical check ROADMAP.md asked for.
    func testCurrentModelConstantsAreStillServed() async throws {
        let served = Set(try await client.models.list(limit: 1000).data.map(\.id))
        let current: [Model] = [.claudeFable52, .claudeOpus55, .claudeSonnet5, .claudeHaiku55]
        for model in current {
            XCTAssertTrue(served.contains(model.rawValue),
                          "\(model.rawValue) is documented as current here but the API does not list it")
        }
    }
}
