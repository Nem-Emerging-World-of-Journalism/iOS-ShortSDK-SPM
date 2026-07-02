//
//  ShortsVideoBrief.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 16/01/24.
//

import Foundation

public struct ShortsVideoBrief: Codable {
    public struct EventVideo: Codable {
        let url: String?
    }

    public struct Publisher: Codable {
        let id: String?
        let name: String?
    }

    public struct PublishedAt: Codable {
        let date: String?
        let agoFromNow: String?
    }

    public let id: String?
    public let title: String?
    public let video: EventVideo?
    public let publisher: Publisher?
    public let publishedAt: PublishedAt?
    public let dataSource: String?
}
