// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "AWLDebugTool",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        // Dynamic, so store builds can drop the SDK completely (see "Store builds" in ios/README.md).
        .library(
            name: "AWLDebugTool",
            type: .dynamic,
            targets: ["AWLDebugTool"]),
        .library(
            name: "AWLDebugFeedback",
            type: .dynamic,
            targets: ["AWLDebugFeedback"]),
    ],
    targets: [
        .target(
            name: "AWLDebugTool",
            path: "ios/Sources",
            exclude: ["AWLDebugFeedback"],
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "AWLDebugToolTests",
            dependencies: ["AWLDebugTool"],
            path: "ios/Tests",
            exclude: ["AWLDebugFeedbackTests"]),
        .target(
            name: "AWLDebugFeedback",
            path: "ios/Sources/AWLDebugFeedback"),
        .testTarget(
            name: "AWLDebugFeedbackTests",
            dependencies: ["AWLDebugFeedback"],
            path: "ios/Tests/AWLDebugFeedbackTests"),
    ]
)
