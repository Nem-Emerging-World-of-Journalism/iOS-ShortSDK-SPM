//
//  ShortsResources.swift
//  JioNewsShortsSDK
//
//  Locates the SDK's compiled resource bundle (icon asset catalog) so the
//  icons ship inside the pod and render in any host app — not only one that
//  happens to have these assets in its own catalog.
//

import SwiftUI

final class ShortsResources {
    /// The bundle that contains the SDK's compiled `Media.xcassets`.
    /// Under SwiftPM the asset catalog is compiled into the package's generated
    /// resource bundle, exposed as `Bundle.module`. With CocoaPods + `use_frameworks!`
    /// the resource bundle lived inside a `JioNewsShortsSDK.bundle`; those lookups are
    /// kept as fallbacks for a framework / main-bundle build.
    static let bundle: Bundle = {
        let frameworkBundle = Bundle(for: ShortsResources.self)
        let candidates: [Bundle?] = [
            .module,
            frameworkBundle.url(forResource: "JioNewsShortsSDK", withExtension: "bundle").flatMap(Bundle.init(url:)),
            Bundle.main.url(forResource: "JioNewsShortsSDK", withExtension: "bundle").flatMap(Bundle.init(url:))
        ]
        return candidates.compactMap { $0 }.first ?? .module
    }()

    private init() {}
}

extension Image {
    /// Loads an image from the SDK's resource bundle.
    init(shorts name: String) {
        self.init(name, bundle: ShortsResources.bundle)
    }
}
