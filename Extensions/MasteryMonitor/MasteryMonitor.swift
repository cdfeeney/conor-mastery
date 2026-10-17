@preconcurrency import DeviceActivity
import Foundation

/// Runs while the app is closed. Every interval start or end re-runs the same shared resolver
/// (GatePolicy over the App Group snapshot), so overlapping intervals can't fight each other:
/// a social window never opens apps during Locked In, wind-down never cancels a paid unblock early.
final class MasteryMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        SharedGate.applyResolved()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        SharedGate.applyResolved()
    }
}
