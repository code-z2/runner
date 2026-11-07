// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RunnerEscrow",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "RunnerEscrow", targets: ["RunnerEscrow"])
    ],
    targets: [
        .target(name: "RunnerEscrow", path: "Sources/RunnerEscrow")
    ]
)
