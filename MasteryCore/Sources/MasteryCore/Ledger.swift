import Foundation

public enum GritReason: String, Codable, Sendable {
    case habit, focus, challenge, task, purchase, landExpansion, unblock, penalty, refund, treat, drop, lesson
}

/// Append-only grit history. The balance is always derived, never stored.
/// Spending is refused below zero, but clawbacks (undoing a paid habit or task) always reverse in full,
/// so the balance may go negative: undo-after-spending must never be a way to farm grit.
public struct GritTransaction: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let day: DayKey
    public let amount: Int
    public let reason: GritReason
    /// What it was for: habit id, item id, session id.
    public let ref: String
    /// XP earned with this event (XP only ever comes from rewards, never purchases).
    public let xp: Int

    public init(id: String = UUID().uuidString, day: DayKey, amount: Int, reason: GritReason, ref: String, xp: Int = 0) {
        self.id = id; self.day = day; self.amount = amount; self.reason = reason; self.ref = ref; self.xp = xp
    }
}

/// Where earned grit came from, as the Dojo names it. Spending (shop, land, unblock, treats) is not earning.
public enum EarnSource: String, Sendable, Hashable {
    case habits, focus, challenge, tasks, lesson

    init?(_ reason: GritReason) {
        switch reason {
        case .habit, .refund: self = .habits
        case .focus, .penalty: self = .focus
        case .challenge: self = .challenge
        case .task: self = .tasks
        case .lesson: self = .lesson
        case .purchase, .landExpansion, .unblock, .treat, .drop: return nil
        }
    }
}

public enum LedgerError: Error, Equatable, Sendable {
    case insufficientGrit(needed: Int, balance: Int)
}

public struct GritLedger: Sendable {
    public let transactions: [GritTransaction]

    public init(_ transactions: [GritTransaction] = []) {
        self.transactions = transactions
    }

    public var balance: Int { transactions.reduce(0) { $0 + $1.amount } }

    public var totalXP: Int { Swift.max(transactions.reduce(0) { $0 + $1.xp }, 0) }

    public var level: LevelProgress { Leveling.progress(totalXP: totalXP) }

    /// What a day earned, net of undos and downgrades, spending left out: positives alone over-counted a habit
    /// paid and then undone, and "+39 grit" matched nothing on screen (gate run 39314550527).
    public func earned(on day: DayKey) -> Int {
        earnedBySource(on: day).reduce(0) { $0 + $1.grit }
    }

    /// Today's earnings by where they came from, biggest first, sources that net to zero left out.
    public func earnedBySource(on day: DayKey) -> [(source: EarnSource, grit: Int)] {
        var totals: [EarnSource: Int] = [:]
        for t in transactions where t.day == day {
            if let source = EarnSource(t.reason) { totals[source, default: 0] += t.amount }
        }
        return totals.filter { $0.value > 0 }.map { (source: $0.key, grit: $0.value) }
            .sorted { $0.grit != $1.grit ? $0.grit > $1.grit : $0.source.rawValue < $1.source.rawValue }
    }

    public func appending(_ transaction: GritTransaction) -> GritLedger {
        GritLedger(transactions + [transaction])
    }

    /// Spending never takes the balance below zero.
    public func spending(_ cost: Int, day: DayKey, reason: GritReason, ref: String) throws -> GritLedger {
        guard cost <= balance else { throw LedgerError.insufficientGrit(needed: cost, balance: balance) }
        return appending(GritTransaction(day: day, amount: -cost, reason: reason, ref: ref))
    }
}
