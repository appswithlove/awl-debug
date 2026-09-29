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
            path: "ios/Tests"),
    ]
)
