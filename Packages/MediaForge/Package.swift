// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MediaForge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "MediaCore", targets: ["MediaCore"]),
        .library(name: "MediaUI", targets: ["MediaUI"]),
        .library(name: "MediaTesting", targets: ["MediaTesting"])
    ],
    targets: [
        // No AppKit, SwiftUI, or Vision, so Linux `swift test` builds this.
        // UITestingEnvironment, RollingLogStore, DebugLog, and ProgressThrottle live here.
        .target(name: "MediaCore"),
        // SwiftUI is behind `#if canImport(SwiftUI)` in Sources/MediaUI.
        .target(name: "MediaUI"),
        // UITestFixtureBuilder. XCTest is behind `#if canImport(XCTest)` so Linux builds it.
        .target(name: "MediaTesting"),
        .testTarget(name: "MediaCoreTests", dependencies: ["MediaCore"]),
        .testTarget(name: "MediaUITests", dependencies: ["MediaUI"]),
        .testTarget(name: "MediaTestingTests", dependencies: ["MediaTesting"])
    ]
)
