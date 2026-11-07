// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerGateway",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerGateway", targets: ["RunnerGateway"])
    ],
    targets: [
        .target(name: "RunnerGateway", path: "Sources/RunnerGateway")
    ]
)
