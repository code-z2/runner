// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerPacePilot",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerPacePilot", targets: ["RunnerPacePilot"])
    ],
    targets: [
        .target(name: "RunnerPacePilot", path: "Sources/RunnerPacePilot")
    ]
)
