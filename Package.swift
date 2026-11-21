// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dial",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "DialCore",
            targets: ["DialCore"]
        )
    ],
    targets: [
        .target(
            name: "DialCore",
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .testTarget(
            name: "DialCoreTests",
            dependencies: ["DialCore"]
        )
    ]
)
