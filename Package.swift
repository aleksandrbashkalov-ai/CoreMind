// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CoreMind",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CoreMind", targets: ["CoreMind"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
    ],
    targets: [
        .executableTarget(
            name: "CoreMind",
            dependencies: [
                .product(name: "GRDB", package: "grdb.swift"),
            ],
            path: "Sources/CoreMind",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "CoreMindTests",
            dependencies: ["CoreMind"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ]
)
