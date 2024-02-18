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
        .package(url: "https://github.com/apple/swift-nio", from: "2.63.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "1.0.0-alpha.11"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),

        .package(url: "https://github.com/OperatorFoundation/Chord.git", from: "0.1.4"),
        .package(url: "https://github.com/OperatorFoundation/KeychainCli", from: "1.0.1"),
        .package(url: "https://github.com/OperatorFoundation/Net", from: "0.0.10"),
        .package(url: "https://github.com/OperatorFoundation/Transmission", from: "1.2.11"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionAsync", from: "0.1.4"),
    ],
    targets: [
        .target(
            name: "Antiphony",
            dependencies: [
                "KeychainCli",
                "Net",
                "Transmission",
                "TransmissionAsync",
                .product(name: "Lifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio"),
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
                "TransmissionAsync",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .executableTarget(
            name: "AntiphonyDemoClient",
            dependencies: [
                "Antiphony",
                "AntiphonyDemo",
                "Chord",
                "TransmissionAsync",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "AntiphonyTests",
            dependencies: ["Antiphony"]),
    ],
    swiftLanguageVersions: [.v5]
)
