// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerLocation",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerLocation", targets: ["RunnerLocation"])
    ],
    targets: [
        .target(name: "RunnerLocation", path: "Sources/RunnerLocation")
    ]
)
