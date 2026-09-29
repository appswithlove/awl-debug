// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "AWLDebugTool",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "AWLDebugTool",
            targets: ["AWLDebugTool"]),
        .library(
            name: "AWLDebugFeedback",
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
