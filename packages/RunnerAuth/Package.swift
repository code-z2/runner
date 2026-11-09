// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "RunnerAuth",
  platforms: [.iOS(.v26), .macOS(.v15)],
  products: [
    .library(name: "RunnerAuth", targets: ["RunnerAuth"]),
    .library(name: "RunnerAuthTesting", targets: ["RunnerAuthTesting"]),
  ],
  dependencies: [
    .package(path: "../RunnerNear"),
  ],
  targets: [
    .target(
      name: "RunnerAuth",
      dependencies: [.product(name: "RunnerNear", package: "RunnerNear")],
      path: "Sources/RunnerAuth"
    ),
    .target(
      name: "RunnerAuthTesting",
      dependencies: ["RunnerAuth"],
      path: "Sources/RunnerAuthTesting"
    ),
    .testTarget(
      name: "RunnerAuthTests",
      dependencies: [
        "RunnerAuth",
        "RunnerAuthTesting",
        .product(name: "RunnerNear", package: "RunnerNear"),
      ],
      path: "Tests/RunnerAuthTests"
    ),
  ]
)
