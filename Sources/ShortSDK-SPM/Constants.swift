//
//  Constants.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 11/01/24.
//

import Foundation

internal struct Constants {
    // GraphQL endpoint is now environment-driven — see `JioShortsEnvironment`
    // and `GraphQLService.endpoint` (set via `ShortsView.initData(env:)`).
    static let platform = "iOS"
    static let language = "English"
    static let source = "Direct"
    static let contentType = "Shorts"
}
