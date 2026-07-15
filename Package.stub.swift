// swift-tools-version: 6.0
import PackageDescription

/// Stub-only manifest (no FluidAudio). Activate with:
///   cp Package.stub.swift Package.swift && swift build
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
    dependencies: [],
    targets: [
        .target(
            name: "FastFlowPlugins",
            dependencies: [],
            path: "Sources/FastFlowPlugins"
        ),
        .executableTarget(
            name: "FastFlow",
            dependencies: ["FastFlowPlugins"],
            path: "Sources/FastFlow"
        ),
        .executableTarget(
            name: "FastFlowBench",
            dependencies: ["FastFlowPlugins"],
            path: "Sources/FastFlowBench"
        ),
        .testTarget(
            name: "FastFlowTests",
            dependencies: ["FastFlowPlugins"],
            path: "Tests/FastFlowTests"
        ),
    ]
)
