// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacFanControl",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "MacFanControlLocalization",
            resources: [.process("Resources")]
        ),
        .target(
            name: "MacFanControlCore",
            path: "Sources/MacFanControlCore",
            linkerSettings: [
                .linkedFramework("Metal"),
            ]
        ),
        .executableTarget(
            name: "macfancontrol",
            dependencies: [
                "MacFanControlCore",
                "MacFanControlLocalization",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/macfancontrol"
        ),
        .executableTarget(
            name: "MacFanControlApp",
            dependencies: ["MacFanControlCore", "MacFanControlLocalization"],
            path: "Sources/MacFanControlApp"
        ),
        .testTarget(
            name: "MacFanControlTests",
            dependencies: ["MacFanControlCore", "MacFanControlApp", "MacFanControlLocalization"],
            path: "Tests/MacFanControlTests"
        ),
    ]
)
