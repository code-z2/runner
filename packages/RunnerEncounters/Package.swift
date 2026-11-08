// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerEncounters",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerEncounters", targets: ["RunnerEncounters"]),
        .library(name: "RunnerEncountersTesting", targets: ["RunnerEncountersTesting"]),
    ],
    targets: [
        .target(name: "RunnerEncounters", path: "Sources/RunnerEncounters"),
        .target(
            name: "RunnerEncountersTesting",
            dependencies: ["RunnerEncounters"],
            path: "Sources/RunnerEncountersTesting"
        ),
        .testTarget(
            name: "RunnerEncountersTests",
            dependencies: ["RunnerEncounters", "RunnerEncountersTesting"],
            path: "Tests/RunnerEncountersTests"
        ),
    ]
)
