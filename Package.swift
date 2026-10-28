// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "AWLDebugTool",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        // Dynamic, so store builds can drop the SDK completely (see "Store builds" in README.md).
        .library(
            name: "AWLDebugTool",
            type: .dynamic,
            targets: ["AWLDebugTool"]),
    ],
    targets: [
        .target(
            name: "AWLDebugTool",
            path: "ios/Sources",
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "AWLDebugToolTests",
            dependencies: ["AWLDebugTool"],
            path: "ios/Tests",
            resources: [.copy("AWLDebugToolTests/Fixtures")]),
    ]
)
