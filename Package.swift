// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacFanPro",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "MacFanProLocalization",
            resources: [.process("Resources")]
        ),
        .target(
            name: "MacFanProCore",
            path: "Sources/MacFanProCore",
            linkerSettings: [
                .linkedFramework("Metal"),
            ]
        ),
        .executableTarget(
            name: "macfanpro",
            dependencies: [
                "MacFanProCore",
                "MacFanProLocalization",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/macfanpro"
        ),
        .executableTarget(
            name: "MacFanProApp",
            dependencies: ["MacFanProCore", "MacFanProLocalization"],
            path: "Sources/MacFanProApp"
        ),
        .testTarget(
            name: "MacFanProTests",
            dependencies: ["MacFanProCore", "MacFanProApp", "MacFanProLocalization"],
            path: "Tests/MacFanProTests"
        ),
    ]
)
