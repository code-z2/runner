// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerEncounters",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "RunnerEncounters", targets: ["RunnerEncounters"])
    ],
    targets: [
        .target(name: "RunnerEncounters", path: "Sources/RunnerEncounters")
    ]
)
