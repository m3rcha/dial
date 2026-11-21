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
        ),
        .executable(
            name: "DialApp",
            targets: ["DialApp"]
        )
    ],
    targets: [
        .target(
            name: "DialCore",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .executableTarget(
            name: "DialApp",
            dependencies: ["DialCore"]
        ),
        .testTarget(
            name: "DialCoreTests",
            dependencies: ["DialCore"]
        )
    ]
)
