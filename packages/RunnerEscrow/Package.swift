// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerEscrow",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerEscrow", targets: ["RunnerEscrow"]),
        .library(name: "RunnerEscrowTesting", targets: ["RunnerEscrowTesting"]),
    ],
    dependencies: [
        .package(path: "../RunnerNear")
    ],
    targets: [
        .target(
            name: "RunnerEscrow",
            dependencies: [.product(name: "RunnerNear", package: "RunnerNear")],
            path: "Sources/RunnerEscrow"
        ),
        .target(
            name: "RunnerEscrowTesting",
            dependencies: ["RunnerEscrow"],
            path: "Sources/RunnerEscrowTesting"
        ),
        .testTarget(
            name: "RunnerEscrowTests",
            dependencies: [
                "RunnerEscrow",
                "RunnerEscrowTesting",
                .product(name: "RunnerNear", package: "RunnerNear"),
                .product(name: "RunnerNearTesting", package: "RunnerNear"),
            ],
            path: "Tests/RunnerEscrowTests"
        ),
    ]
)
