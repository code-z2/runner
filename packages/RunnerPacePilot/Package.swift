// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RunnerPacePilot",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RunnerPacePilot", targets: ["RunnerPacePilot"]),
        .library(name: "RunnerPacePilotTesting", targets: ["RunnerPacePilotTesting"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/soniqo/speech-swift",
            revision: "31d676c6a7f1a3f9e3004c06914de54e61f0f987"
        ),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "RunnerPacePilot",
            dependencies: [
                .product(name: "KokoroTTS", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/RunnerPacePilot"
        ),
        .target(
            name: "RunnerPacePilotTesting",
            dependencies: ["RunnerPacePilot"],
            path: "Sources/RunnerPacePilotTesting"
        ),
        .testTarget(
            name: "RunnerPacePilotTests",
            dependencies: ["RunnerPacePilot", "RunnerPacePilotTesting"],
            path: "Tests/RunnerPacePilotTests"
        ),
    ]
)
