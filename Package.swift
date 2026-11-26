// swift-tools-version:5.9
import PackageDescription

// Thin umbrella so the repo root is a valid Swift package.
// Sources live only in Packages/MediaForge. A root `swift test` does not run
// that package's tests; CI and scripts/verify-linux.sh test it by path.
let package = Package(
    name: "media-forge",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "Packages/MediaForge")
    ],
    targets: [
        .testTarget(
            name: "UmbrellaTests",
            dependencies: [
                .product(name: "MediaCore", package: "MediaForge"),
                .product(name: "MediaUI", package: "MediaForge"),
                .product(name: "MediaTesting", package: "MediaForge")
            ]
        )
    ]
)
