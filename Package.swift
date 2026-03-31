// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "anthropic-swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "Anthropic", targets: ["Anthropic"]),
        .library(name: "AnthropicTestSupport", targets: ["AnthropicTestSupport"]),
    ],
    targets: [
        // Main SDK library
        .target(
            name: "Anthropic",
            path: "Sources/Anthropic",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Test utilities — not shipped to end-users
        .target(
            name: "AnthropicTestSupport",
            dependencies: ["Anthropic"],
            path: "Sources/AnthropicTestSupport"
        ),
        // Test suite
        .testTarget(
            name: "AnthropicTests",
            dependencies: ["Anthropic", "AnthropicTestSupport"],
            path: "Tests/AnthropicTests"
        ),
        // Examples
        .executableTarget(
            name: "BasicChat",
            dependencies: ["Anthropic"],
            path: "Examples/BasicChat"
        ),
        .executableTarget(
            name: "StreamingChat",
            dependencies: ["Anthropic"],
            path: "Examples/StreamingChat"
        ),
        .executableTarget(
            name: "ToolUse",
            dependencies: ["Anthropic"],
            path: "Examples/ToolUse"
        ),
        .executableTarget(
            name: "FileUpload",
            dependencies: ["Anthropic"],
            path: "Examples/FileUpload"
        ),
        .executableTarget(
            name: "BatchProcessing",
            dependencies: ["Anthropic"],
            path: "Examples/BatchProcessing"
        ),
    ]
)
