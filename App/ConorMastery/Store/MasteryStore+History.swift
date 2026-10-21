import Foundation
import MasteryCore

/// The streak's minimum on Today, whole-routine swipes, and the GitHub-style history (owner 10-21).
extension MasteryStore {
    /// One history row: a plan habit, or a routine with its steps (and its pre-split whole version).
    struct HistoryRow: Identifiable {
        let id: String
        let title: String
        let habits: [HabitDefinition]
    }

    /// Required today and not done yet: what stands between you and today's Perfect Day.
    var streakOpen: [HabitDefinition] {
        StreakKeeper.open(habits, index: index, on: today, timeZone: timeZone)
    }

    func routine(_ routineID: String) -> HabitDefinition? { planHabits.first { $0.id == routineID } }

    func steps(ofRoutine routineID: String) -> [HabitDefinition] { habits.filter { $0.routine == routineID } }

    /// Swipe on a routine header: Done marks every step full; Min marks the open steps Min (full steps stay full).
    func logRoutine(_ level: CompletionLevel, routineID: String) {
        let open = steps(ofRoutine: routineID).filter { completion($0.id)?.level != .full }
        batch { open.forEach { log(level, habitID: $0.id) } }
    }

    func clearRoutine(_ routineID: String) {
        let logged = steps(ofRoutine: routineID).filter { completion($0.id) != nil }
        batch { logged.forEach { clear(habitID: $0.id) } }
    }

    /// Current habits in plan order, then archived and deleted ones (their history stays visible).
    var historyRows: [HistoryRow] {
        let groups = Dictionary(grouping: state.habits) { $0.routine ?? $0.id }
        let current = planHabits.map(\.id)
        let gone = groups.keys.filter { !current.contains($0) }.sorted()
        return (current + gone).compactMap { id in
            guard let defs = groups[id] else { return nil }
            let title = effectivePlanHabits.first { $0.id == id }?.title
                ?? settings.retiredHabits.last { $0.habit.id == id }?.habit.title ?? defs[0].title
            return HistoryRow(id: id, title: current.contains(id) ? title : "\(title) (off)", habits: defs)
        }
    }

    func historyMark(_ habits: [HabitDefinition], on day: DayKey) -> HistoryMark {
        HabitHistory.mark(habits, on: day, today: today, start: settings.startDay, index: index,
                          restDays: settings.restDays, timeZone: timeZone)
    }

    /// Every habit at once. Past days follow the streak's own verdict, so the grid always agrees with the streak.
    func perfectDayMark(on day: DayKey) -> HistoryMark {
        switch streak.outcomes[day] {
        case .saved: return .saved
        case .missed: return .missed
        case .rest: return .off
        case .perfect, .pending, nil: return historyMark(state.habits, on: day)
        }
    }
}
