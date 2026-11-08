// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerAuth",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "RunnerAuth", targets: ["RunnerAuth"])
    ],
    targets: [
        .target(name: "RunnerAuth", path: "Sources/RunnerAuth")
    ]
)
