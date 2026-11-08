// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerGateway",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerGateway", targets: ["RunnerGateway"]),
        .library(name: "RunnerGatewayTesting", targets: ["RunnerGatewayTesting"]),
    ],
    targets: [
        .target(name: "RunnerGateway", path: "Sources/RunnerGateway"),
        .target(
            name: "RunnerGatewayTesting",
            dependencies: ["RunnerGateway"],
            path: "Sources/RunnerGatewayTesting"
        ),
        .testTarget(
            name: "RunnerGatewayTests",
            dependencies: ["RunnerGateway", "RunnerGatewayTesting"],
            path: "Tests/RunnerGatewayTests"
        ),
    ]
)
