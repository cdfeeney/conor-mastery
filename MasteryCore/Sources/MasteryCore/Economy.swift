import Foundation

public struct Reward: Codable, Sendable, Hashable {
    public let grit: Int
    public let xp: Int

    public init(grit: Int, xp: Int) {
        self.grit = grit
        self.xp = xp
    }

    public static let zero = Reward(grit: 0, xp: 0)

    public static func + (lhs: Reward, rhs: Reward) -> Reward {
        Reward(grit: lhs.grit + rhs.grit, xp: lhs.xp + rhs.xp)
    }
}

/// All game-economy numbers in one place (PRD section 4).
public enum RewardRules {
    public static let xpPerHabit = 10
    public static let xpPerFocusMinute = 1
    public static let xpSleepOnTarget = 10
    public static let focusMinutesPerGrit = 5
    public static let lockedInMultiplier = 1.5
    public static let lockedInEarlyStopPenalty = 10
    public static let dailyChallengeGrit = 20
    public static let taskGrit = 3
    public static let streakBonusBlockDays = 7
    public static let streakBonusMax = 5
    public static let unblockGritCost = 25
    public static let unblockMinutes = 15

    public static func baseGrit(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 5
        case .medium: return 10
        case .hard: return 15
        }
    }

    /// +1 grit per full 7-day block of the current streak, capped.
    public static func streakBonus(streakDays: Int) -> Int {
        Swift.min(Swift.max(streakDays, 0) / streakBonusBlockDays, streakBonusMax)
    }

    public static func habitReward(difficulty: Difficulty, level: CompletionLevel, streakDays: Int) -> Reward {
        switch level {
        case .notDone, .slipped:
            return .zero
        case .full:
            return Reward(grit: baseGrit(difficulty) + streakBonus(streakDays: streakDays), xp: xpPerHabit)
        case .minimum:
            // Half pay, rounded up so the minimum is never worth nothing.
            let grit = (baseGrit(difficulty) + 1) / 2 + streakBonus(streakDays: streakDays)
            return Reward(grit: grit, xp: xpPerHabit)
        }
    }

    /// Focus pays per minute actually focused. Locked-In multiplies grit; stopping early costs grit.
    public static func focusReward(minutes: Int, lockedIn: Bool, stoppedEarly: Bool) -> Reward {
        let safeMinutes = Swift.max(minutes, 0)
        let xp = safeMinutes * xpPerFocusMinute
        let base = Double(safeMinutes / focusMinutesPerGrit)
        if lockedIn && stoppedEarly {
            return Reward(grit: Int(base) - lockedInEarlyStopPenalty, xp: xp)
        }
        let grit = lockedIn ? Int((base * lockedInMultiplier).rounded(.down)) : Int(base)
        return Reward(grit: grit, xp: xp)
    }
}

public enum Belt: String, Codable, Sendable, CaseIterable {
    case white, yellow, orange, green, blue, purple, brown, black

    public var title: String { rawValue.capitalized + " Belt" }

    public static func forLevel(_ level: Int) -> Belt {
        switch level {
        case ..<5: return .white
        case 5..<10: return .yellow
        case 10..<15: return .orange
        case 15..<20: return .green
        case 20..<30: return .blue
        case 30..<40: return .purple
        case 40..<50: return .brown
        default: return .black
        }
    }
}

public struct LevelProgress: Sendable, Hashable {
    public let level: Int
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int
    public var belt: Belt { Belt.forLevel(level) }
    public var fraction: Double {
        xpForNextLevel == 0 ? 0 : Double(xpIntoLevel) / Double(xpForNextLevel)
    }
}

public enum Leveling {
    /// Cumulative XP needed to reach `level` (level 1 = 0 XP, level 2 = 100, level 3 = 300 ...).
    public static func xpToReach(level: Int) -> Int {
        let l = Swift.max(level, 1)
        return 50 * l * (l - 1)
    }

    public static func progress(totalXP: Int) -> LevelProgress {
        let xp = Swift.max(totalXP, 0)
        var level = 1
        while xpToReach(level: level + 1) <= xp { level += 1 }
        let floor = xpToReach(level: level)
        let next = xpToReach(level: level + 1)
        return LevelProgress(level: level, xpIntoLevel: xp - floor, xpForNextLevel: next - floor)
    }
}
