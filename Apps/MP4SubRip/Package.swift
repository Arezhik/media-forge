// swift-tools-version:5.9
import PackageDescription

let package = Package(
    // Not "MP4SubRip". That is the Xcode project's name, and the IDE drops the
    // products when the package and the project share a name and a folder.
    name: "MP4SubRipKit",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "MP4SubRipCore", targets: ["MP4SubRipCore"])
    ],
    dependencies: [
        .package(path: "../../Packages/MediaForge")
    ],
    targets: [
        // Core logic only: no AppKit, SwiftUI, or Vision imports, so `swift test`
        // runs on Linux (cloud agents and the Linux CI job) as well as on a Mac.
        .target(
            name: "MP4SubRipCore",
            dependencies: [
                .product(name: "MediaCore", package: "MediaForge")
            ]
        ),
        .testTarget(
            name: "MP4SubRipCoreTests",
            dependencies: [
                "MP4SubRipCore",
                .product(name: "MediaCore", package: "MediaForge")
            ]
        )
    ]
)
