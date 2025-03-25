// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CheckUpdate",
    defaultLocalization: .init(rawValue: "en"),
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "CheckUpdate",
            targets: ["CheckUpdate"]),
    ],
    targets: [
        .target(
            name: "CheckUpdate",
            resources:  [.process("Resources")]
        ),

    ]
)
