// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerPacePilot",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerPacePilot", targets: ["RunnerPacePilot"]),
        .library(name: "RunnerPacePilotTesting", targets: ["RunnerPacePilotTesting"]),
    ],
    targets: [
        .target(name: "RunnerPacePilot", path: "Sources/RunnerPacePilot"),
        .target(
            name: "RunnerPacePilotTesting",
            dependencies: ["RunnerPacePilot"],
            path: "Sources/RunnerPacePilotTesting"
        ),
        .testTarget(
            name: "RunnerPacePilotTests",
            dependencies: ["RunnerPacePilot", "RunnerPacePilotTesting"],
            path: "Tests/RunnerPacePilotTests"
        ),
    ]
)
