// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerAuth",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerAuth", targets: ["RunnerAuth"])
    ],
    targets: [
        .target(name: "RunnerAuth", path: "Sources/RunnerAuth")
    ]
)
