// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerSession",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerSession", targets: ["RunnerSession"]),
        .library(name: "RunnerSessionTesting", targets: ["RunnerSessionTesting"]),
    ],
    targets: [
        .target(name: "RunnerSession", path: "Sources/RunnerSession"),
        .target(
            name: "RunnerSessionTesting",
            dependencies: ["RunnerSession"],
            path: "Sources/RunnerSessionTesting"
        ),
        .testTarget(
            name: "RunnerSessionTests",
            dependencies: ["RunnerSession", "RunnerSessionTesting"],
            path: "Tests/RunnerSessionTests"
        ),
    ]
)
