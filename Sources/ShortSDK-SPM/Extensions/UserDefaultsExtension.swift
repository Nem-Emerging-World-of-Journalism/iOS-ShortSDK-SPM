//
//  UserDefaultsExtension.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 23/01/24.
//

import Foundation

extension UserDefaults {
    private enum Keys {
        static let isShortsMuted = "SHORTS_SDK_MUTED"
        static let hid = "SHORTS_SDK_HID"
    }

    internal class var isShortsMuted: Bool? {
        get {
            return UserDefaults.standard.value(forKey: Keys.isShortsMuted) as? Bool
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isShortsMuted)
            UserDefaults.standard.synchronize()
        }
    }

    /// Last `hid` (Authorization token) passed to `configure`, kept so the SDK
    /// can fall back to it when a later call omits the value.
    internal class var hid: String? {
        get {
            return UserDefaults.standard.value(forKey: Keys.hid) as? String
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hid)
            UserDefaults.standard.synchronize()
        }
    }
}
