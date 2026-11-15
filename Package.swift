// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickDrop",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "QuickDropCore",
            targets: ["QuickDropCore"]
        ),
        .executable(
            name: "QuickDrop",
            targets: ["QuickDrop"]
        )
    ],
    targets: [
        .target(
            name: "QuickDropCore",
            path: "Sources/QuickDropCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "QuickDrop",
            dependencies: ["QuickDropCore"],
            path: "Sources/QuickDrop"
        ),
        .testTarget(
            name: "QuickDropTests",
            dependencies: ["QuickDropCore"],
            path: "Tests/QuickDropTests"
        )
    ]
)
