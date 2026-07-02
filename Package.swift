// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShortSDK-SPM",
    // The SDK uses UIKit / SwiftUI / AVFoundation. Minimum supported OS is iOS 15.1;
    // newer APIs (iOS 16/17 scroll + Locale) are guarded with `if #available`.
    platforms: [
        .iOS("15.1")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ShortSDK-SPM",
            targets: ["ShortSDK-SPM"]
        ),
    ],
    dependencies: [
        // `import CleverTapSDK` is used by Analytics / ShortsController / ShortsView.
        .package(url: "https://github.com/CleverTap/clevertap-ios-sdk", from: "7.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ShortSDK-SPM",
            dependencies: [
                .product(name: "CleverTapSDK", package: "clevertap-ios-sdk"),
            ],
            exclude: [
                // Framework umbrella header — only meaningful for a CocoaPods/framework
                // build, unused by SwiftPM.
                "JioNewsShortsSDK.h",
                // Vendored SkeletonView documentation assets (images/gifs) and README
                // translations — not source, would be flagged as unhandled resources.
                "SkeletonView/Assets",
                "SkeletonView/Translations",
                // Vendored SkeletonView tests (currently commented out) — do not belong
                // in the library target.
                "SkeletonView/SkeletonViewCore/Tests",
            ],
            resources: [
                // Icon asset catalog shipped inside the module.
                .process("Media.xcassets"),
            ]
        ),

    ],
    // The vendored SkeletonView (and `GraphQLService.shared`) are written in the
    // pre-concurrency Swift model and do not compile cleanly under Swift 6's strict
    // concurrency checking, so the package builds in the Swift 5 language mode.
    swiftLanguageModes: [.v5]
)
