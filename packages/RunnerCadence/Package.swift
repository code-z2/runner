// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerCadence",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerCadence", targets: ["RunnerCadence"]),
        .library(name: "RunnerCadenceTesting", targets: ["RunnerCadenceTesting"]),
    ],
    targets: [
        .target(name: "RunnerCadence", path: "Sources/RunnerCadence"),
        .target(
            name: "RunnerCadenceTesting",
            dependencies: ["RunnerCadence"],
            path: "Sources/RunnerCadenceTesting"
        ),
        .testTarget(
            name: "RunnerCadenceTests",
            dependencies: ["RunnerCadence", "RunnerCadenceTesting"],
            path: "Tests/RunnerCadenceTests"
        ),
    ]
)
