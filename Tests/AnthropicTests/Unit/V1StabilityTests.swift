import XCTest
@testable import Anthropic
import AnthropicTestSupport

/// The behaviours that changed at 1.0 (see MIGRATION.md).
final class V1StabilityTests: XCTestCase {

    private let base = URL(string: "https://api.anthropic.com")!
    private let request = MessageRequest(model: .claudeSonnet5, messages: [.user("hi")], maxTokens: 16)

    private func client(_ mock: MockHTTPClient) -> AnthropicClient {
        AnthropicClient(configuration: ClientConfiguration(apiKey: "test-key", baseURL: base, maxRetries: 0, httpClient: mock))
    }

    // MARK: - A response that does not say where it came from is refused

    func testAResponseWithNoURLIsRefusedOnAUnaryCall() async throws {
        let mock = MockHTTPClient()
        mock.reportsResponseURL = false
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        do {
            _ = try await client(mock).messages.create(request)
            XCTFail("a response with no url was accepted")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }

    func testAStreamWithNoURLIsRefusedBeforeAnyByteIsDelivered() async throws {
        let mock = MockHTTPClient()
        mock.reportsResponseURL = false
        mock.streamHandler = { _ in SSEFixtures.lineStream(from: SSEFixtures.basicMessageStream) }
        var events = 0
        do {
            for try await _ in client(mock).messages.stream(request) { events += 1 }
            XCTFail("a stream with no url was delivered")
        } catch AnthropicError.networkError(let error) {
            XCTAssertEqual(error.code, .badServerResponse)
        }
        XCTAssertEqual(events, 0)
    }

    func testThePipelineHandsTheClientTheConfiguredBaseURL() async throws {
        let mock = MockHTTPClient()
        mock.handler = { _ in HTTPResponse(statusCode: 200, body: MockResponses.singleMessage) }
        _ = try await client(mock).messages.create(request)
        XCTAssertEqual(mock.recordedRequests.first?.baseURL, base)
    }

    // MARK: - Batch outcomes

    func testAnUnrecognisedBatchOutcomeIsUnknownNotCanceled() throws {
        let json = Data(#"{"custom_id":"q1","result":{"type":"paused"}}"#.utf8)
        let item = try JSONCoding.decoder.decode(BatchResult.self, from: json)
        guard case .unknown(let type) = item.result else {
            return XCTFail("expected .unknown, got \(item.result)")
        }
        XCTAssertEqual(type, "paused")
    }

    // MARK: - Caller input refused before sending

    func testASkillWithoutASkillMdIsInvalidRequestAndSendsNothing() async throws {
        let mock = MockHTTPClient()
        mock.handler = { _ in XCTFail("no request should be sent"); return HTTPResponse(statusCode: 200) }
        do {
            _ = try await client(mock).skills.create(files: [SkillFile(path: "s/other.md", content: Data())])
            XCTFail("expected an error")
        } catch AnthropicError.invalidRequest(let message) {
            XCTAssertTrue(message.contains("SKILL.md"), message)
        }
    }

    // MARK: - The advertised version

    func testTheAdvertisedVersionIsTheLatestReleasedChangelogHeading() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let text = try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        let released = text.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix("## ["), !line.hasPrefix("## [Unreleased]"),
                  let end = line.firstIndex(of: "]") else { return nil }
            return String(line[line.index(line.startIndex, offsetBy: 4)..<end])
        }
        XCTAssertEqual(Anthropic.version, released.first)
    }
}
