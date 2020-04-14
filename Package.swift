// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fusion",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "fusion",
            type: .dynamic,
            targets: ["fusion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tcldr/Entwine.git", from: "0.8.0"),
    ],
    targets: [
        .target(
            name: "fusion",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "fusionTests",
            dependencies: ["fusion", "EntwineTest"],
            path: "Tests"),
    ]
)
