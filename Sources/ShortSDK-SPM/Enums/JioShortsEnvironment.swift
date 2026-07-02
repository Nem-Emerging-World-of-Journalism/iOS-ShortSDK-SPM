//
//  JioShortsEnvironment.swift
//  JioNewsShortsSDK
//
//  API environment passed to `ShortsView.initData(env:)`. Selects the GraphQL
//  backend the SDK talks to.
//

import Foundation

public enum JioShortsEnvironment {
    /// Staging backend.
    case stg
    /// Production backend.
    case prod

    /// GraphQL endpoint for this environment.
    var graphQLURL: URL {
        switch self {
        case .stg:  return URL(string: "https://stgmobileservice.jionews.com/graphql")!
        case .prod: return URL(string: "https://mobileservice.jionews.com/graphql")!
        }
    }
}
