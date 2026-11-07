// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerLocation",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerLocation", targets: ["RunnerLocation"]),
        .library(name: "RunnerLocationTesting", targets: ["RunnerLocationTesting"]),
    ],
    targets: [
        .target(name: "RunnerLocation", path: "Sources/RunnerLocation"),
        .target(
            name: "RunnerLocationTesting",
            dependencies: ["RunnerLocation"],
            path: "Sources/RunnerLocationTesting"
        ),
        .testTarget(
            name: "RunnerLocationTests",
            dependencies: ["RunnerLocation", "RunnerLocationTesting"],
            path: "Tests/RunnerLocationTests"
        ),
    ]
)
