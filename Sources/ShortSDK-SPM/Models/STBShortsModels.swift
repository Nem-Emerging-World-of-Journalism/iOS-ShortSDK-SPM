//
//  STBShortsModels.swift
//  JioNewsShortsSDK
//
//  GraphQL models for the native (AVPlayer) shorts feed — the
//  `getNativeShorts` query. Ported from the DemoShorts native feed; the
//  YouTube (`getShorts`) models are intentionally omitted.
//

import Foundation

// MARK: - Shared GraphQL primitives

struct GraphQLErrorEntry: Decodable {
    let message: String
}

struct CountText: Decodable {
    let text: String?
    let unit: String?
    let count: Int?
}

struct PublishedAt: Decodable {
    let agoFromNow: String?
    let date: String?
    let prettyDateTime: String?
}

struct Cursor: Decodable {
    let prev: Int?
    let curr: Int?
    let next: Int?
    let totalPages: Int?
    let totalDocs: Int?
    let totalDocsText: String?
    let size: Int?
}

// MARK: - getNativeShorts response

struct GetNativeShortsResponseRoot: Decodable {
    let data: GetNativeShortsResponseData?
    let errors: [GraphQLErrorEntry]?
}

struct GetNativeShortsResponseData: Decodable {
    let getNativeShorts: GetNativeShortsResult?
}

struct GetNativeShortsResult: Decodable {
    let newsBriefs: [STBNewsBrief]?
    let cursor: Cursor?
    let dateTime: String?
}

// MARK: - newsBriefById response

struct NewsBriefByIdResponseRoot: Decodable {
    let data: NewsBriefByIdData?
    let errors: [GraphQLErrorEntry]?
}

struct NewsBriefByIdData: Decodable {
    let newsBriefById: NewsBriefByIdResult?
}

struct NewsBriefByIdResult: Decodable {
    let newsBrief: STBNewsBrief?
}

struct STBNewsBrief: Decodable, Identifiable {
    let id: String
    let video: STBVideo?
    let title: String?
    let thumbnail: STBThumbnail?
    let videoId: String?
    let shareCount: CountText?
    let publishedAt: PublishedAt?
    let publisher: STBPublisher?
    let type: String?
    let reactions: STBReactions?
    let dataSource: String?
    let publisherLink: String?
    let language: STBLanguage?
    let thumbnailURL_v2: STBThumbnailURLv2?
    let redirectionURLV1: String?
    let source: String?
    let category: STBCategory?
}

struct STBCategory: Decodable {
    let title: String?
    let id: String?
    let parentName: String?
}

struct STBVideo: Decodable {
    let duration: Double?
    let url: String?
}

struct STBThumbnail: Decodable {
    let url: String?
}

struct STBPublisher: Decodable {
    let id: String?
    let name: String?
}

struct STBLanguage: Decodable {
    let id: String?
    let name: String?
}

struct STBReactions: Decodable {
    let total: Int?
    let userReaction: String?
    /// In the GraphQL query this is aliased: `reactionType: reactions { ... }`.
    let reactionType: [STBReaction]?
}

struct STBReaction: Decodable, Identifiable {
    let type: String?
    let count: Int?
    let text: String?
    let unit: String?
    var id: String { type ?? UUID().uuidString }
}

struct STBThumbnailURLv2: Decodable {
    let defaultVariant: STBThumbnailVariant?
    let medium: STBThumbnailVariant?
    let high: STBThumbnailVariant?
    let standard: STBThumbnailVariant?
    let maxres: STBThumbnailVariant?

    enum CodingKeys: String, CodingKey {
        case defaultVariant = "default"
        case medium, high, standard, maxres
    }
}

struct STBThumbnailVariant: Decodable {
    let url: String?
}

// MARK: - Reaction mutations (addNewsBriefReaction / resetNewsBriefReaction)

struct AddReactionResponseRoot: Decodable {
    let data: AddReactionData?
    let errors: [GraphQLErrorEntry]?
}

struct AddReactionData: Decodable {
    let addNewsBriefReaction: ReactionMutationPayload?
}

struct ResetReactionResponseRoot: Decodable {
    let data: ResetReactionData?
    let errors: [GraphQLErrorEntry]?
}

struct ResetReactionData: Decodable {
    let resetNewsBriefReaction: ReactionMutationPayload?
}

struct ReactionMutationPayload: Decodable {
    let errors: [String]?
    let reactions: ReactionMutationReactions?
}

struct ReactionMutationReactions: Decodable {
    let total: Int?
    let userReaction: String?
    let reactions: [STBReaction]?
    let TotalPrettytext: String?
}

// MARK: - Convenience

extension STBNewsBrief {
    /// Best available video URL (HTTPS, mp4 or HLS).
    var videoURL: URL? {
        guard let s = video?.url, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    /// Best available thumbnail URL string.
    var bestThumbnailURLString: String? {
        if let s = thumbnail?.url, !s.isEmpty { return s }
        if let s = thumbnailURL_v2?.maxres?.url, !s.isEmpty { return s }
        if let s = thumbnailURL_v2?.high?.url, !s.isEmpty { return s }
        if let s = thumbnailURL_v2?.standard?.url, !s.isEmpty { return s }
        if let s = thumbnailURL_v2?.medium?.url, !s.isEmpty { return s }
        if let s = thumbnailURL_v2?.defaultVariant?.url, !s.isEmpty { return s }
        return nil
    }

    /// Like count display text — only when the count is greater than 0.
    var likeText: String? {
        guard let r = reactions?.reactionType?.first(where: {
            let t = ($0.type ?? "").lowercased()
            return t.contains("like") && !t.contains("dislike")
        }) else { return nil }
        return Self.positiveCountText(text: r.text, count: r.count)
    }

    /// Numeric like count (the "like" reaction's count), if present.
    var likeCount: Int? {
        reactions?.reactionType?.first {
            let t = ($0.type ?? "").lowercased()
            return t.contains("like") && !t.contains("dislike")
        }?.count
    }

    /// Share count display text — only when the count is greater than 0.
    var shareText: String? {
        Self.positiveCountText(text: shareCount?.text, count: shareCount?.count)
    }

    var dislikeText: String? {
        reactions?.reactionType?.first { ($0.type ?? "").lowercased().contains("dislike") }
            .flatMap { $0.text ?? $0.count.map(String.init) }
    }

    /// Returns the display text only when the count is positive; otherwise nil.
    private static func positiveCountText(text: String?, count: Int?) -> String? {
        if let count = count { return count > 0 ? (text ?? String(count)) : nil }
        if let text = text, !text.isEmpty, text != "0" { return text }
        return nil
    }

    /// Maps the internal STB brief onto the public `ShortsVideoBrief` payload
    /// that's surfaced to host apps via the delegate / `currentVideoBrief`.
    func asShortsVideoBrief() -> ShortsVideoBrief {
        ShortsVideoBrief(
            id: id,
            title: title,
            video: ShortsVideoBrief.EventVideo(url: video?.url),
            publisher: ShortsVideoBrief.Publisher(id: publisher?.id, name: publisher?.name),
            publishedAt: ShortsVideoBrief.PublishedAt(date: publishedAt?.date, agoFromNow: publishedAt?.agoFromNow),
            dataSource: dataSource
        )
    }
}
