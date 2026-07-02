//
//  ShortsAnalytics.swift
//  JioNewsShortsSDK
//
//  CleverTap event tracking for the Shorts feed. One function per event from
//  the analytics spec. Common + content properties are built here; callers
//  just pass the event-specific values.
//

import Foundation
import CleverTapSDK

final class ShortsAnalytics {

    private let theme: JioShortsTheme
    /// Logged-in user id (session id); set after loginWeb.
    var userId: String?

    init(theme: JioShortsTheme) {
        self.theme = theme
    }

    // MARK: - Events

    /// `shorts_feed_load` — user lands on the Shorts section.
    func feedLoad(loadTime: Int, apiError: String?) {
        var props = base(apiError: apiError)
        props["load_time"] = loadTime
        record("shorts_feed_load", props)
    }

    /// `shorts_feed_exit` — user exits the Shorts section.
    func feedExit(viewTime: Int, viewCount: Int) {
        var props = base()
        props["view_time"] = viewTime
        props["view_count"] = viewCount
        record("shorts_feed_exit", props)
    }

    /// `shorts_view` — user navigates away from a short that was playing.
    /// `contentDuration` is the real AVPlayer asset duration (seconds).
    func shortsView(item: STBNewsBrief, swipe: String, watchedTime: Int, contentDuration: Int) {
        var props = base().merging(content(item, swipe: swipe)) { $1 }
        props["watched_time"] = watchedTime
        props["content_duration"] = contentDuration
        record("shorts_view", props)
    }

    /// `content_like` — user likes a short.
    func contentLike(item: STBNewsBrief, swipe: String) {
        record("content_like", base().merging(content(item, swipe: swipe)) { $1 })
    }

    /// `content_like_remove` — user unlikes a short.
    func contentLikeRemove(item: STBNewsBrief, swipe: String) {
        record("content_like_remove", base().merging(content(item, swipe: swipe)) { $1 })
    }

    /// `content_share_select` — user taps the share button.
    func shareSelect(item: STBNewsBrief, swipe: String) {
        record("content_share_select", base().merging(content(item, swipe: swipe)) { $1 })
    }

    /// `content_share_submit` — content successfully shared.
    /// Note: the host app performs the actual share (via `onShareClick`), so the
    /// SDK has no completion signal — call this from the host when share succeeds.
    func shareSubmit(item: STBNewsBrief, swipe: String) {
        record("content_share_submit", base().merging(content(item, swipe: swipe)) { $1 })
    }

    /// `report_content` — user reports a piece of content.
    /// Note: there is no report UI in the SDK yet, so this is currently unused.
    func reportContent(item: STBNewsBrief) {
        record("report_content", base().merging(content(item, swipe: "NA")) { $1 })
    }

    // MARK: - Property builders

    private func base(apiError: String? = nil) -> [String: Any] {
        [
            "screen": "Shorts",
            "section": "Shorts",
            "content_type": "Shorts",
            "api_error": apiError ?? "NA",
            "source": "Direct",
            "language": Self.language,
            "platform": "iOS",
            "app_version": Self.appVersion,
            "dark_mode": theme == .dark ? "True" : "False",
            "user_id": userId ?? "NA"
        ]
    }

    private func content(_ item: STBNewsBrief, swipe: String) -> [String: Any] {
        [
            "category": item.category?.title ?? "NA",
            "category_id": item.category?.id ?? "NA",
            "pub_date_time": item.publishedAt?.date ?? "NA",
            "publisher_id": item.publisher?.id ?? "NA",
            "publisher_name": item.publisher?.name ?? "NA",
            "content_id": item.id,
            "content_title": item.title ?? "NA",
            "swipe": swipe,
            "dataSource": item.dataSource ?? "NA"
        ]
    }

    private func record(_ name: String, _ props: [String: Any]) {
        CleverTap.sharedInstance()?.recordEvent(name, withProps: props)
    }

    private static let appVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "NA"

    private static let language: String = {
        if #available(iOS 16.0, *) {
            return Locale.current.language.languageCode?.identifier ?? "NA"
        } else {
            return Locale.current.languageCode ?? "NA"
        }
    }()
}
