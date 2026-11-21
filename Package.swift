// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Forevermem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Forevermem", targets: ["Forevermem"]),
        .executable(name: "ForevermemCLI", targets: ["ForevermemCLI"])
    ],
    targets: [
        .target(
            name: "Forevermem",
            path: "Sources/Forevermem"
        ),
        .executableTarget(
            name: "ForevermemCLI",
            dependencies: ["Forevermem"],
            path: "Examples/ForevermemCLI"
        ),
        .testTarget(
            name: "ForevermemTests",
            dependencies: ["Forevermem"],
            path: "Tests/ForevermemTests"
        )
    ]
)
