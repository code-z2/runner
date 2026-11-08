// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerHealthKit",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerHealthKit", targets: ["RunnerHealthKit"]),
        .library(name: "RunnerHealthKitTesting", targets: ["RunnerHealthKitTesting"]),
    ],
    dependencies: [
        .package(path: "../RunnerSession")
    ],
    targets: [
        .target(
            name: "RunnerHealthKit",
            dependencies: [.product(name: "RunnerSession", package: "RunnerSession")],
            path: "Sources/RunnerHealthKit"
        ),
        .target(
            name: "RunnerHealthKitTesting",
            dependencies: ["RunnerHealthKit"],
            path: "Sources/RunnerHealthKitTesting"
        ),
        .testTarget(
            name: "RunnerHealthKitTests",
            dependencies: [
                "RunnerHealthKit",
                "RunnerHealthKitTesting",
                .product(name: "RunnerSession", package: "RunnerSession"),
            ],
            path: "Tests/RunnerHealthKitTests"
        ),
    ]
)
