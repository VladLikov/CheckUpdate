// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CheckUpdate",
    defaultLocalization: .init(rawValue: "en"),
    platforms: [.iOS(.v15)],
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

    ],
    swiftLanguageModes: [.v6]
)
