import XCTest
@testable import Anthropic

final class JSONCodingTests: XCTestCase {

    func testEncoderUsesSnakeCase() throws {
        struct TestStruct: Encodable {
            let maxTokens: Int
            let stopSequence: String
        }
        let obj = TestStruct(maxTokens: 1024, stopSequence: "END")
        let data = try JSONCoding.encoder.encode(obj)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(dict?["max_tokens"])
        XCTAssertNotNil(dict?["stop_sequence"])
        XCTAssertNil(dict?["maxTokens"])
    }

    func testDecoderUsesSnakeCase() throws {
        struct TestStruct: Decodable, Equatable {
            let inputTokens: Int
            let outputTokens: Int
        }
        let json = #"{"input_tokens":10,"output_tokens":5}"#
        let decoded = try JSONCoding.decoder.decode(TestStruct.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.inputTokens, 10)
        XCTAssertEqual(decoded.outputTokens, 5)
    }

    func testUsageRoundTrip() throws {
        let usage = Usage(inputTokens: 42, outputTokens: 7)
        let data = try JSONCoding.encoder.encode(usage)
        let decoded = try JSONCoding.decoder.decode(Usage.self, from: data)
        XCTAssertEqual(usage, decoded)
    }

    func testModelEncodesAsString() throws {
        let model = Model.claude4Opus
        let data = try JSONCoding.encoder.encode(model)
        let str = String(data: data, encoding: .utf8)
        XCTAssertEqual(str, "\"claude-opus-4-5\"")
    }

    func testCountTokensResponseDecoding() throws {
        let json = #"{"input_tokens":42}"#
        let decoded = try JSONCoding.decoder.decode(CountTokensResponse.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.inputTokens, 42)
    }
}
