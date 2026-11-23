import Foundation
import UIKit
import BackgroundTasks

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Permanent ruling, Tyler 2026-11-22: Town's relevanceScore is 100 in
/// every state, forever. Any other value is a defect.
///
/// The score is a single named constant on purpose: it is referenced at
/// every ActivityContent construction site (request, update, restart) and
/// is NEVER conditional — no "alert ? high : low" branching anywhere.
enum TownPresenceScore {
    static let value: Double = 100
}

/// Facade for Town's Live Activity ("the island").
///
/// Callable from AppDelegate on any supported OS version — all ActivityKit
/// work is hidden behind availability checks inside this file, so call sites
/// need no annotations. The app's deployment target is iOS 15.0; Live
/// Activities exist from iOS 16.2, and on anything older every entry point
/// here is a safe no-op (background refresh still registers/schedules).
enum TownPresence {

    static let backgroundTaskIdentifier = "com.buckthem.town.presence-refresh"

    // MARK: Entry points (called from AppDelegate)

    /// Registers the background refresh task. Must be called before the app
    /// finishes launching (AppDelegate calls this from didFinishLaunching).
    static func bootstrap() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            handleBackgroundRefresh(task: task)
        }
        syncNow()
    }

    /// Kicks off an asynchronous Square sync (no-op pre-iOS 16.2).
    static func syncNow() {
        if #available(iOS 16.2, *) {
            TownPresenceWorker.shared.sync()
        }
    }

    /// Schedules the next background refresh (~2 hours out). Called whenever
    /// the app enters the background and again after each background run.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Scheduling is best-effort; foreground syncs cover the gap.
        }
    }

    // MARK: Background task handling

    private static func handleBackgroundRefresh(task: BGTask) {
        // Reschedule first so the cadence survives whatever happens below.
        scheduleBackgroundRefresh()

        guard let refreshTask = task as? BGAppRefreshTask else {
            task.setTaskCompleted(success: false)
            return
        }

        let completion = TownPresenceCompletionBox()
        refreshTask.expirationHandler = {
            completion.finish(task: refreshTask, success: false)
        }

        if #available(iOS 16.2, *) {
            TownPresenceWorker.shared.sync {
                completion.finish(task: refreshTask, success: true)
            }
        } else {
            completion.finish(task: refreshTask, success: true)
        }
    }
}

/// One-shot guard so a BG task is completed exactly once (either by the sync
/// finishing or by the system expiring the task).
private final class TownPresenceCompletionBox {
    private let lock = NSLock()
    private var finished = false

    func finish(task: BGTask, success: Bool) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()
        task.setTaskCompleted(success: success)
    }
}

// MARK: - Worker (iOS 16.2+)

@available(iOS 16.2, *)
final class TownPresenceWorker {

    static let shared = TownPresenceWorker()

    private static let startedAtKey = "town-presence-started-at"
    private static let lastHeadlineKey = "town-presence-last-headline"
    private static let lastDetailKey = "town-presence-last-detail"
    private static let lastFreshCountKey = "town-presence-last-fresh-count"

    private static let feedURL = URL(string: "https://imintown.app/town/actions")!
    private static let staleInterval: TimeInterval = 1800
    private static let maxActivityAge: TimeInterval = 7 * 60 * 60

    private var syncInFlight = false

    private init() {}

    // MARK: Sync

    func sync(completion: (() -> Void)? = nil) {
        guard !syncInFlight else {
            completion?()
            return
        }
        syncInFlight = true
        Task {
            await self.performSync()
            self.syncInFlight = false
            completion?()
        }
    }

    private func performSync() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let existing = Activity<TownPresenceAttributes>.activities.first

        guard let state = await fetchState() else {
            // Fetch failed: never invent content. If an activity is already
            // running, just push its stale date out with the last known state.
            if let activity = existing, let last = lastKnownState() {
                let content = ActivityContent(
                    state: last,
                    staleDate: Date(timeIntervalSinceNow: Self.staleInterval),
                    relevanceScore: TownPresenceScore.value
                )
                await activity.update(content)
            }
            return
        }

        remember(state: state)

        let content = ActivityContent(
            state: state,
            staleDate: Date(timeIntervalSinceNow: Self.staleInterval),
            relevanceScore: TownPresenceScore.value
        )

        guard let activity = existing else {
            await startActivity(with: content)
            return
        }

        // Recycle activities older than ~7 hours so the island stays fresh
        // and inside the system's good graces. The end + restart uses the
        // iOS 17 end API (the pre-17 end(using:) form is gone from current
        // SDKs); on iOS 16.x the activity is simply updated and the
        // system's own 8-hour cap ends it — the next sync after that
        // starts a fresh one.
        if #available(iOS 17.0, *),
           let startedAt = recordedStartDate(),
           Date().timeIntervalSince(startedAt) > Self.maxActivityAge {
            await activity.end(nil, dismissalPolicy: .immediate)
            await startActivity(with: content)
        } else {
            if recordedStartDate() == nil {
                recordStartDate(Date())
            }
            await activity.update(content)
        }
    }

    private func startActivity(with content: ActivityContent<TownPresenceAttributes.ContentState>) async {
        do {
            _ = try Activity.request(
                attributes: TownPresenceAttributes(),
                content: content,
                pushType: nil
            )
            recordStartDate(Date())
        } catch {
            // Activities may be refused (disabled, too many, etc.) — the next
            // foreground sync will try again.
        }
    }

    // MARK: Feed

    private struct FeedResponse: Decodable {
        struct DataPayload: Decodable {
            struct Post: Decodable {
                var body: String?
                var createdAt: String?
            }
            var posts: [Post]?
        }
        var data: DataPayload?
    }

    /// Fetches the Square feed and reduces it to a content state.
    /// Returns nil on ANY failure (network, HTTP, decode) so the caller can
    /// fall back to refreshing staleness instead of inventing content.
    private func fetchState() async -> TownPresenceAttributes.ContentState? {
        var request = URLRequest(url: Self.feedURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["action": "getSquareFeed", "args": ["limit": 30]]
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return nil
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(FeedResponse.self, from: data),
              let posts = decoded.data?.posts else {
            return nil
        }

        let now = Date()
        var freshCount = 0
        for post in posts {
            if let created = parseDate(post.createdAt),
               now.timeIntervalSince(created) <= 3600 {
                freshCount += 1
            }
        }

        let headline = freshCount > 0 ? "New on the Square" : "The Square"

        var detail = "The Square is open"
        if let newestBody = posts.first?.body {
            let collapsed = newestBody
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !collapsed.isEmpty {
                detail = truncate(collapsed, to: 60)
            }
        }

        return TownPresenceAttributes.ContentState(
            headline: headline,
            detail: detail,
            freshCount: freshCount
        )
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    private func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<end]) + "…"
    }

    // MARK: Persistence (start time + last known state)

    private func recordStartDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.startedAtKey)
    }

    private func recordedStartDate() -> Date? {
        let stamp = UserDefaults.standard.double(forKey: Self.startedAtKey)
        guard stamp > 0 else { return nil }
        return Date(timeIntervalSince1970: stamp)
    }

    private func remember(state: TownPresenceAttributes.ContentState) {
        let defaults = UserDefaults.standard
        defaults.set(state.headline, forKey: Self.lastHeadlineKey)
        defaults.set(state.detail, forKey: Self.lastDetailKey)
        defaults.set(state.freshCount, forKey: Self.lastFreshCountKey)
    }

    private func lastKnownState() -> TownPresenceAttributes.ContentState? {
        let defaults = UserDefaults.standard
        guard let headline = defaults.string(forKey: Self.lastHeadlineKey),
              let detail = defaults.string(forKey: Self.lastDetailKey) else {
            return nil
        }
        return TownPresenceAttributes.ContentState(
            headline: headline,
            detail: detail,
            freshCount: defaults.integer(forKey: Self.lastFreshCountKey)
        )
    }
}
