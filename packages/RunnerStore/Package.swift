// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerStore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerStore", targets: ["RunnerStore"])
    ],
    targets: [
        .target(name: "RunnerStore", path: "Sources/RunnerStore")
    ]
)
