// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerEncounters",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerEncounters", targets: ["RunnerEncounters"])
    ],
    targets: [
        .target(name: "RunnerEncounters", path: "Sources/RunnerEncounters")
    ]
)
