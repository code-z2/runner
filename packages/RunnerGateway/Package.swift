// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerGateway",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "RunnerGateway", targets: ["RunnerGateway"])
    ],
    targets: [
        .target(name: "RunnerGateway", path: "Sources/RunnerGateway")
    ]
)
