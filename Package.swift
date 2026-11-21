// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Foreverloom",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Foreverloom", targets: ["Foreverloom"]),
        .executable(name: "ForeverloomCLI", targets: ["ForeverloomCLI"])
    ],
    targets: [
        .target(
            name: "Foreverloom",
            path: "Sources/Foreverloom"
        ),
        .executableTarget(
            name: "ForeverloomCLI",
            dependencies: ["Foreverloom"],
            path: "Examples/ForeverloomCLI"
        ),
        .testTarget(
            name: "ForeverloomTests",
            dependencies: ["Foreverloom"],
            path: "Tests/ForeverloomTests"
        )
    ]
)
