// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerStore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerStore", targets: ["RunnerStore"]),
        .library(name: "RunnerStoreTesting", targets: ["RunnerStoreTesting"]),
    ],
    dependencies: [
        .package(path: "../RunnerSession")
    ],
    targets: [
        .target(
            name: "RunnerStore",
            dependencies: [.product(name: "RunnerSession", package: "RunnerSession")],
            path: "Sources/RunnerStore"
        ),
        .target(
            name: "RunnerStoreTesting",
            dependencies: ["RunnerStore"],
            path: "Sources/RunnerStoreTesting"
        ),
        .testTarget(
            name: "RunnerStoreTests",
            dependencies: [
                "RunnerStore",
                "RunnerStoreTesting",
                .product(name: "RunnerSession", package: "RunnerSession"),
            ],
            path: "Tests/RunnerStoreTests"
        ),
    ]
)
