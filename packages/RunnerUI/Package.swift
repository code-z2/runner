// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerUI",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerUI", targets: ["RunnerUI"]),
    ],
    targets: [
        .target(
            name: "RunnerUI",
            path: "Sources/RunnerUI",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RunnerUITests",
            dependencies: ["RunnerUI"],
            path: "Tests/RunnerUITests"
        ),
    ]
)
