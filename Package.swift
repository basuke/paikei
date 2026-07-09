// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Paikei",
    products: [
        .library(name: "PaikeiCore", targets: ["PaikeiCore"]),
        .executable(name: "paikei", targets: ["paikei"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "PaikeiCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "paikei",
            dependencies: [
                "PaikeiCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PaikeiCoreTests",
            dependencies: ["PaikeiCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
