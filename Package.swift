// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickDrop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "QuickDrop",
            targets: ["QuickDrop"]
        )
    ],
    targets: [
        .executableTarget(
            name: "QuickDrop",
            path: "Sources/QuickDrop"
        )
    ]
)
