// swift-tools-version: 6.0
//
// This package exists so the pure finance engine and its tests can run with
// `swift test` on macOS or Linux — no simulator required. The Xcode project
// compiles the very same files into the app target; the SPM target named
// `LevelUpYourLife` deliberately matches the app's module name so the test
// files' `@testable import LevelUpYourLife` works in both worlds.

import PackageDescription

let package = Package(
    name: "LevelUpYourLifeEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LevelUpYourLifeEngine", targets: ["LevelUpYourLife"]),
    ],
    targets: [
        .target(
            name: "LevelUpYourLife",
            path: "LevelUpYourLife",
            sources: ["Engine"]
        ),
        .testTarget(
            name: "LevelUpYourLifeEngineTests",
            dependencies: ["LevelUpYourLife"],
            path: "LevelUpYourLifeTests"
        ),
    ]
)
