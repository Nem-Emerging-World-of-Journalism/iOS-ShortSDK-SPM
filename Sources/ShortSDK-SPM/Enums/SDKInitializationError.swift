//
//  SDKInitializationError.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 15/01/24.
//

import Foundation

enum SDKInitializationError: Error {
    case hidEmpty
    case invalidClient

    var message: String {
        switch self {
        case .hidEmpty:
            return "hid is empty. call configure() method with a valid hid (and none is saved in local storage)"
        case .invalidClient:
            return "Invalid client, to enable shorts SDK for your client, contact JioNews Team!!"
        }
    }
}
