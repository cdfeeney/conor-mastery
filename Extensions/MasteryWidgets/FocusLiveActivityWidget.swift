import ActivityKit
import SwiftUI
import WidgetKit

/// Lock screen + Dynamic Island for a running focus session. Text(timerInterval:) counts down on its own.
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(attributes: context.attributes, state: context.state, isDone: context.isStale)
                .activityBackgroundTint(WidgetTheme.background)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "conormastery://focus"))
        } dynamicIsland: { context in
            let interval = context.attributes.startedAt...context.state.endsAt
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HeroSprite(belt: context.attributes.belt, size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: interval, countsDown: true)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.lockedIn ? "Locked in: apps blocked" : "Focusing")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.attributes.lockedIn ? "lock.fill" : "flame.fill").foregroundStyle(WidgetTheme.accent)
            } compactTrailing: {
                Text(timerInterval: interval, countsDown: true).monospacedDigit().frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "flame.fill").foregroundStyle(WidgetTheme.accent)
            }
            .widgetURL(URL(string: "conormastery://focus"))
        }
    }
}

struct FocusLockScreenView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState
    /// Past the end time (stale): the session is over even if the app hasn't run yet.
    let isDone: Bool

    var body: some View {
        if isDone { done } else { running }
    }

    private var done: some View {
        HStack(spacing: 14) {
            HeroSprite(belt: attributes.belt, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Label("Session done", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(WidgetTheme.jade)
                Text("\(attributes.plannedMinutes) minutes focused. Open Mastery to collect your grit.").font(.caption)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    private var running: some View {
        let interval = attributes.startedAt...state.endsAt
        return HStack(spacing: 14) {
            HeroSprite(belt: attributes.belt, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Label(attributes.lockedIn ? "Locked in" : "Focusing",
                      systemImage: attributes.lockedIn ? "lock.fill" : "flame.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(WidgetTheme.accent)
                Text(timerInterval: interval, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                ProgressView(timerInterval: interval, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(WidgetTheme.jade)
                if let note = attributes.note { Text(note).font(.caption).lineLimit(1).foregroundStyle(.secondary) }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

struct HeroSprite: View {
    let belt: String
    let size: CGFloat
    var body: some View {
        Image("hero-\(belt)").resizable().interpolation(.none).frame(width: size, height: size)
    }
}
