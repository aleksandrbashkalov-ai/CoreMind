// swift-tools-version: 6.0
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
                .swiftLanguageVersion(.v6),
            ]
        ),
        .testTarget(
            name: "CoreMindTests",
            dependencies: ["CoreMind"],
            swiftSettings: [
                .swiftLanguageVersion(.v6),
            ]
        ),
    ]
)
