import Foundation

/// Energy (0-100): the softened loss mechanic from the approved v0.2 design (docs/briefing, section 4).
/// Missed habits drain it and grey out the garden; a Perfect Day or a level-up refills it; a miss followed
/// by a done day refunds half that miss ("never miss twice"). It never kills you or takes levels away.
public enum EnergyRules {
    public static let max = 100
    public static let start = 100
    public static func drain(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 6
        case .medium: return 9
        case .hard: return 12
        }
    }
    public static let perfectDayRefill = 25
}

public struct EnergyState: Sendable, Hashable {
    public let value: Int
    /// 0 = full colour, 1 = fully grey (for the garden's colour grade).
    public var greyness: Double { 1 - Double(value) / Double(EnergyRules.max) }
}

public enum EnergyEngine {
    /// Replays `start ..< end` (end exclusive: today's misses aren't misses yet).
    /// `levelUpDays` are days on which the player reached a new level (refill to full).
    public static func evaluate(habits: [HabitDefinition], completions: [Completion], from start: DayKey,
                                until end: DayKey, restDays: Set<DayKey> = [], levelUpDays: Set<DayKey> = [],
                                timeZone: TimeZone = .current) -> EnergyState {
        let index = CompletionIndex(completions)
        var energy = EnergyRules.start
        /// Drain from yesterday's misses, per habit, so today's recovery can refund half.
        var pendingRefund: [String: Int] = [:]
        guard start < end else { return EnergyState(value: energy) }
        for day in DayKey.range(start, through: end.adding(days: -1, timeZone: timeZone), timeZone: timeZone) {
            if restDays.contains(day) {
                pendingRefund = [:]
                continue
            }
            let required = habits.filter { $0.isRequired(on: day, timeZone: timeZone) }
            var missedToday: [String: Int] = [:]
            for habit in required {
                if index.isDone(habit.id, on: day) {
                    if let owed = pendingRefund[habit.id] { energy += owed / 2 }
                } else {
                    let drain = EnergyRules.drain(habit.difficulty)
                    energy -= drain
                    missedToday[habit.id] = drain
                }
            }
            if !required.isEmpty && missedToday.isEmpty { energy += EnergyRules.perfectDayRefill }
            if levelUpDays.contains(day) { energy = EnergyRules.max }
            energy = Swift.min(Swift.max(energy, 0), EnergyRules.max)
            pendingRefund = missedToday
        }
        return EnergyState(value: energy)
    }

    /// Days on which cumulative XP crossed into a new level, from the ledger.
    public static func levelUpDays(_ ledger: GritLedger) -> Set<DayKey> {
        var days: Set<DayKey> = []
        var xp = 0
        var level = 1
        let byDay = Dictionary(grouping: ledger.transactions, by: \.day).sorted { $0.key < $1.key }
        for (day, txs) in byDay {
            xp += txs.reduce(0) { $0 + $1.xp }
            let now = Leveling.progress(totalXP: xp).level
            if now > level { days.insert(day) }
            level = Swift.max(level, now)
        }
        return days
    }
}
