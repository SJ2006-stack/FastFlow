// swift-tools-version: 6.0
import PackageDescription

// Default manifest: FluidAudio + Parakeet.
// Stub-only (no FluidAudio): `cp Package.stub.swift Package.swift`
//
// Building requires a full Xcode install on some CLT-only machines
// (`xcode-select -s /Applications/Xcode.app/Contents/Developer`).

let package = Package(
    name: "FastFlow",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "FastFlowPlugins", targets: ["FastFlowPlugins"]),
        .executable(name: "FastFlow", targets: ["FastFlow"]),
        .executable(name: "FastFlowBench", targets: ["FastFlowBench"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.0"),
    ],
    targets: [
        .target(
            name: "FastFlowPlugins",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/FastFlowPlugins",
            swiftSettings: [
                .define("FASTFLOW_USE_FLUIDAUDIO"),
            ]
        ),
        .executableTarget(
            name: "FastFlow",
            dependencies: ["FastFlowPlugins"],
            path: "Sources/FastFlow",
            swiftSettings: [
                .define("FASTFLOW_USE_FLUIDAUDIO"),
            ]
        ),
        .executableTarget(
            name: "FastFlowBench",
            dependencies: ["FastFlowPlugins"],
            path: "Sources/FastFlowBench",
            swiftSettings: [
                .define("FASTFLOW_USE_FLUIDAUDIO"),
            ]
        ),
        .testTarget(
            name: "FastFlowTests",
            dependencies: ["FastFlowPlugins"],
            path: "Tests/FastFlowTests"
        ),
    ]
)
