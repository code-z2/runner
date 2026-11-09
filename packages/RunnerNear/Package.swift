// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerNear",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerNear", targets: ["RunnerNear"]),
        .library(name: "RunnerNearTesting", targets: ["RunnerNearTesting"]),
    ],
    targets: [
        .binaryTarget(
            name: "runner_near_coreFFI",
            path: "Frameworks/RunnerNearCoreFFI.xcframework"
        ),
        .target(
            name: "RunnerNearCore",
            dependencies: ["runner_near_coreFFI"],
            path: "Sources/RunnerNearCore",
            linkerSettings: [
                // reqwest's proxy detection (macOS/iOS) lives here.
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("Security"),
            ]
        ),
        .target(
            name: "RunnerNear",
            dependencies: ["RunnerNearCore"],
            path: "Sources/RunnerNear"
        ),
        .target(
            name: "RunnerNearTesting",
            dependencies: ["RunnerNear"],
            path: "Sources/RunnerNearTesting"
        ),
        .testTarget(
            name: "RunnerNearTests",
            dependencies: ["RunnerNear", "RunnerNearTesting"],
            path: "Tests/RunnerNearTests"
        ),
    ]
)
