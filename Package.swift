// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hasami",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Hasami",
            targets: ["Hasami"]),
        .executable(
            name: "sukashi",
            targets: ["sukashi"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Hasami",
            dependencies: [
                .product(name: "SortedCollections", package: "swift-collections")
            ]),
        .executableTarget(
            name: "sukashi",
            dependencies: [
                "Hasami",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "HasamiTests",
            dependencies: ["Hasami"]),
    ]
)
