// swift-tools-version:5.9
import PackageDescription

let package = Package(
    // Not "MediaForgeCatalog". That is the Xcode project's name, and the IDE drops
    // the products when the package and the project share a name and a folder.
    name: "MediaForgeCatalogKit",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "MediaForgeCatalogCore", targets: ["MediaForgeCatalogCore"])
    ],
    targets: [
        // Static catalog data only: no AppKit, SwiftUI, or XCTest, so `swift test`
        // runs on Linux. The app target calls MediaUI itself.
        .target(name: "MediaForgeCatalogCore"),
        .testTarget(
            name: "MediaForgeCatalogCoreTests",
            dependencies: ["MediaForgeCatalogCore"]
        )
    ]
)
