import XCTest
@testable import Anthropic

final class ContentBlockCodingTests: XCTestCase {

    // MARK: - Decode

    func testDecodeTextBlock() throws {
        let json = #"{"type":"text","text":"Hello!"}"#
        let block = try JSONCoding.decoder.decode(ContentBlock.self, from: Data(json.utf8))
        if case .text(let b) = block {
            XCTAssertEqual(b.text, "Hello!")
        } else {
            XCTFail("Expected .text, got \(block)")
        }
    }

    func testDecodeToolUseBlock() throws {
        let json = #"{"type":"tool_use","id":"toolu_01","name":"get_weather","input":{"location":"SF"}}"#
        let block = try JSONCoding.decoder.decode(ContentBlock.self, from: Data(json.utf8))
        if case .toolUse(let b) = block {
            XCTAssertEqual(b.id, "toolu_01")
            XCTAssertEqual(b.name, "get_weather")
        } else {
            XCTFail("Expected .toolUse, got \(block)")
        }
    }

    func testDecodeUnknownBlockTypeDoesNotCrash() throws {
        let json = #"{"type":"future_block_v99","some_field":"value"}"#
        let block = try JSONCoding.decoder.decode(ContentBlock.self, from: Data(json.utf8))
        if case .unknown(let type_, _) = block {
            XCTAssertEqual(type_, "future_block_v99")
        } else {
            XCTFail("Expected .unknown, got \(block)")
        }
    }

    func testDecodeArrayOfBlocks() throws {
        let json = """
        [
          {"type":"text","text":"foo"},
          {"type":"text","text":"bar"},
          {"type":"brand_new_type_9000","extra":123}
        ]
        """
        let blocks = try JSONCoding.decoder.decode([ContentBlock].self, from: Data(json.utf8))
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].text, "foo")
        XCTAssertEqual(blocks[1].text, "bar")
        if case .unknown(let type_, _) = blocks[2] {
            XCTAssertEqual(type_, "brand_new_type_9000")
        } else {
            XCTFail("Expected .unknown")
        }
    }

    // MARK: - Encode / Round-trip

    func testRoundTripTextBlock() throws {
        let block = ContentBlock.text(.init(text: "Hello!"))
        let encoded = try JSONCoding.encoder.encode(block)
        let decoded = try JSONCoding.decoder.decode(ContentBlock.self, from: encoded)
        XCTAssertEqual(block, decoded)
    }

    // MARK: - Convenience

    func testTextConvenienceProperty() throws {
        let block = ContentBlock.text(.init(text: "Convenient"))
        XCTAssertEqual(block.text, "Convenient")

        let toolBlock = ContentBlock.toolUse(.init(id: "id", name: "n", input: [:]))
        XCTAssertNil(toolBlock.text)
    }
}
