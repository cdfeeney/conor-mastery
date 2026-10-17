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

    public func earned(on day: DayKey) -> Int {
        transactions.filter { $0.day == day && $0.amount > 0 }.reduce(0) { $0 + $1.amount }
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
