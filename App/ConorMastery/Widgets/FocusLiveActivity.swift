import ActivityKit
import Foundation
import OSLog

/// Starts and ends the lock-screen / Dynamic Island timer for a focus session. The countdown itself is
/// drawn by the system from the end date, so it keeps ticking while the app is closed.
@MainActor
enum FocusLiveActivity {
    private static let log = Logger(subsystem: "com.conorfee.conormastery", category: "live-activity")

    /// Ends any leftover activity first, so there is never more than one.
    static func start(_ session: ActiveFocus, belt: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let leftovers = Activity<FocusActivityAttributes>.activities
        Task {
            for activity in leftovers { await activity.end(nil, dismissalPolicy: .immediate) }
            request(session, belt: belt)
        }
    }

    private static func request(_ session: ActiveFocus, belt: String) {
        let endsAt = session.startedAt.addingTimeInterval(TimeInterval(session.plannedMinutes * 60))
        let attributes = FocusActivityAttributes(startedAt: session.startedAt, plannedMinutes: session.plannedMinutes,
                                                 lockedIn: session.lockedIn, belt: belt, note: session.note)
        do {
            _ = try Activity.request(attributes: attributes,
                                     content: ActivityContent(state: .init(endsAt: endsAt), staleDate: endsAt))
        } catch {
            // The in-app timer still works; only the lock-screen copy is missing.
            log.error("Focus Live Activity not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// On launch/foreground: end activities with no matching running session, or whose time is up.
    /// (Ending exactly at zero while the app is closed would need an ActivityKit push server; until then the
    /// lock screen shows "Session done" once the content goes stale.)
    static func reconcile(active: ActiveFocus?) {
        let now = Date.now
        let stale = Activity<FocusActivityAttributes>.activities.filter { activity in
            guard let active else { return true }
            return activity.attributes.startedAt != active.startedAt || activity.content.state.endsAt <= now
        }
        guard !stale.isEmpty else { return }
        Task {
            for activity in stale { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Ends every focus activity (there is at most one, but a crash could leave a stray).
    static func endAll() {
        let activities = Activity<FocusActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        Task {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
