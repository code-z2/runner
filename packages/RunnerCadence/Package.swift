// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerCadence",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerCadence", targets: ["RunnerCadence"])
    ],
    targets: [
        .target(name: "RunnerCadence", path: "Sources/RunnerCadence")
    ]
)
