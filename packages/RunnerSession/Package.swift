// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerSession",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RunnerSession", targets: ["RunnerSession"])
    ],
    targets: [
        .target(name: "RunnerSession", path: "Sources/RunnerSession")
    ]
)
