// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerHealthKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "RunnerHealthKit", targets: ["RunnerHealthKit"])
    ],
    targets: [
        .target(name: "RunnerHealthKit", path: "Sources/RunnerHealthKit")
    ]
)
