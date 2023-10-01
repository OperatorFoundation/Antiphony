// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Antiphony",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "Antiphony",
            targets: ["Antiphony"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "1.0.0-alpha.11"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.3"),
        .package(url: "https://github.com/OperatorFoundation/Spacetime", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/KeychainCli", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Net", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Transmission", branch: "main"),
    ],
    targets: [
        .target(
            name: "Antiphony",
            dependencies: [
                "KeychainCli",
                "Net",
                "Transmission",
                .product(name: "Lifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Simulation", package: "Spacetime"),
                .product(name: "Spacetime", package: "Spacetime"),
                .product(name: "Universe", package: "Spacetime"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .target(
            name: "AntiphonyDemo",
            dependencies: []),
        .executableTarget(
            name: "AntiphonyDemoServer",
            dependencies: [
                "Antiphony",
                "AntiphonyDemo",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .executableTarget(
            name: "AntiphonyDemoClient",
            dependencies: [
                "Antiphony",
                "AntiphonyDemo",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "AntiphonyTests",
            dependencies: ["Antiphony"]),
    ],
    swiftLanguageVersions: [.v5]
)
