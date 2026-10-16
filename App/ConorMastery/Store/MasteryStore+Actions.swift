import Foundation
import SwiftData
import MasteryCore

extension MasteryStore {
    // MARK: - Habits

    func log(_ level: CompletionLevel, habitID: String, day: DayKey? = nil, source: CompletionSource = .manual,
             minutes: Int? = nil, stepsDone: [String] = []) {
        let target = day ?? today
        let result = MasteryEngine.log(level, habitID: habitID, day: target, source: source,
                                       minutes: minutes, stepsDone: stepsDone, in: state)
        deleteCompletionRecords(habitID: habitID, day: target)
        context.insert(Self.record(Completion(habitID: habitID, day: target, level: level, source: source,
                                              minutes: minutes, stepsDone: stepsDone)))
        persistLedgerTail(from: state.ledger, to: result.state.ledger)
        setState(result.state)
        save()
        if result.delta.grit > 0 || result.delta.xp > 0 {
            lastReward = RewardToast(title: state.habit(habitID)?.title ?? "Habit", reward: result.delta)
        }
    }

    func clear(habitID: String, day: DayKey? = nil) {
        let target = day ?? today
        let result = MasteryEngine.clear(habitID: habitID, day: target, in: state)
        deleteCompletionRecords(habitID: habitID, day: target)
        persistLedgerTail(from: state.ledger, to: result.state.ledger)
        setState(result.state)
        save()
    }

    /// Checklist ticks are progress; ticking the last step completes the habit in full.
    func toggleStep(_ step: String, habit: HabitDefinition) {
        let current = completion(habit.id)
        let key = Self.draftKey(habit.id, today)
        var steps = current?.stepsDone ?? drafts[key] ?? []
        if let at = steps.firstIndex(of: step) { steps.remove(at: at) } else { steps.append(step) }
        let allDone = !habit.steps.isEmpty && Set(habit.steps).isSubset(of: Set(steps))
        // Drafts are per day, so yesterday's ticks never carry into today.
        drafts = drafts.filter { $0.key.hasSuffix("|\(today.rawValue)") }
        drafts[key] = allDone || steps.isEmpty ? nil : steps
        saveDrafts()
        if allDone { return log(.full, habitID: habit.id, stepsDone: steps) }
        if current?.level == .minimum { return log(.minimum, habitID: habit.id, stepsDone: steps) }
        // Partial progress is not a result yet: no completion until all steps or Min.
        if current != nil { clear(habitID: habit.id) } else { save() }
    }

    private func deleteCompletionRecords(habitID: String, day: DayKey) {
        let raw = day.rawValue
        let rows = (try? context.fetch(FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.habitID == habitID && $0.day == raw }))) ?? []
        rows.forEach(context.delete)
    }

    // MARK: - Sleep

    func logSleep(_ entry: SleepEntry) {
        let raw = entry.wakeDay.rawValue
        let existing = (try? context.fetch(FetchDescriptor<SleepRecord>(predicate: #Predicate { $0.wakeDay == raw }))) ?? []
        existing.forEach(context.delete)
        context.insert(SleepRecord(wakeDay: raw, bedMinutes: entry.bedtime.minutes, wakeMinutes: entry.wakeTime.minutes,
                                   hoursSlept: entry.hoursSlept, quality: entry.quality))
        sleep = (sleep.filter { $0.wakeDay != entry.wakeDay } + [entry]).sorted { $0.wakeDay < $1.wakeDay }
        if let sleepHabit = habits.first(where: { $0.kind == .sleep }) {
            log(MasteryEngine.sleepLevel(entry, target: settings.sleepTarget), habitID: sleepHabit.id,
                day: entry.wakeDay, source: .sleepLog)
        } else {
            save()
        }
    }

    // MARK: - Focus and timers

    func record(focus session: FocusSession) {
        let booked = FocusEngine.record(session, ledger: state.ledger)
        persistLedgerTail(from: state.ledger, to: booked.ledger)
        setState(MasteryState(habits: state.habits, completions: state.completions, ledger: booked.ledger,
                              startDay: state.startDay, strictStreak: state.strictStreak, timeZone: timeZone))
        context.insert(FocusRecord(id: session.id, day: session.day.rawValue, plannedMinutes: session.plannedMinutes,
                                   focusedMinutes: session.focusedMinutes, lockedIn: session.lockedIn,
                                   note: session.note, habitID: session.habitID))
        focus.append(session)
        save()
        lastReward = RewardToast(title: session.lockedIn ? "Locked-in focus" : "Focus", reward: booked.reward)
        if let id = session.habitID { creditMinutes(habitID: id, day: session.day, source: .focus) }
    }

    /// Timer habits (meditation, breathing) credit minutes run today; best level wins.
    func finishTimer(habit: HabitDefinition, minutes: Int) {
        let total = (completion(habit.id)?.minutes ?? 0) + minutes
        guard let level = FocusEngine.habitLevel(minutes: total, habit: habit) else {
            errorMessage = "\(total) min logged. \(habit.minMinutes ?? 1) min counts as the minimum."
            return
        }
        log(level, habitID: habit.id, source: .timer, minutes: total)
    }

    private func creditMinutes(habitID: String, day: DayKey, source: CompletionSource) {
        guard let habit = state.habit(habitID) else { return }
        let minutes = focus.filter { $0.day == day && $0.habitID == habitID }.reduce(0) { $0 + $1.focusedMinutes }
        guard let level = FocusEngine.habitLevel(minutes: minutes, habit: habit) else { return }
        let current = index.completion(habitID, on: day)?.level
        if current == .full || (current == .minimum && level == .minimum) { return }
        log(level, habitID: habitID, day: day, source: source, minutes: minutes)
    }

    // MARK: - Challenge, tasks, reflection

    func completeChallenge() {
        guard let challenge, !challengeDone else { return }
        let next = state.ledger.appending(GritTransaction(day: today, amount: challenge.reward, reason: .challenge,
                                                          ref: "challenge@\(today.rawValue)", xp: RewardRules.xpPerHabit))
        commitLedger(next)
        var s = settings
        s.challengeDoneDay = today
        update(settings: s)
        lastReward = RewardToast(title: "Daily challenge", reward: Reward(grit: challenge.reward, xp: RewardRules.xpPerHabit))
    }

    func addTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(TaskRecord(title: String(trimmed.prefix(120)), day: today.rawValue))
        save()
        reload()
    }

    /// Ticking pays 3 grit; unticking reverses exactly what the task paid (balance may go negative),
    /// so tick/spend/untick/tick can't farm grit.
    func toggle(task: TaskRecord) {
        task.isDone.toggle()
        let ref = "task@\(task.id)"
        let paid = state.ledger.transactions.filter { $0.ref == ref }.reduce(0) { $0 + $1.amount }
        let amount = (task.isDone ? RewardRules.taskGrit : 0) - paid
        if amount != 0 {
            commitLedger(state.ledger.appending(GritTransaction(day: today, amount: amount, reason: .task, ref: ref)))
        }
        save()
    }

    func delete(task: TaskRecord) {
        context.delete(task)
        save()
        reload()
    }

    func saveReflection(_ text: String) {
        let raw = today.rawValue
        let existing = (try? context.fetch(FetchDescriptor<ReflectionRecord>(predicate: #Predicate { $0.day == raw }))) ?? []
        if let row = existing.first { row.text = text } else { context.insert(ReflectionRecord(day: raw, text: text)) }
        reflections[today] = text
        save()
    }

    // MARK: - Shop and world

    func buy(_ item: ShopItem) {
        do {
            let nextWorld = try world.buying(item.id, level: level.level)
            let nextLedger = try state.ledger.spending(item.price, day: today, reason: .purchase, ref: item.id)
            commitLedger(nextLedger)
            replace(world: nextWorld)
            save()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    func place(_ itemID: String, x: Int, y: Int) {
        do { replace(world: try world.placing(itemID, x: x, y: y)); save() } catch { errorMessage = Self.describe(error) }
    }

    func pickUp(x: Int, y: Int) {
        do { replace(world: try world.removing(atX: x, y: y)); save() } catch { errorMessage = Self.describe(error) }
    }

    func expandLand() {
        guard let next = world.nextExpansion else { return }
        do {
            let nextLedger = try state.ledger.spending(next.price, day: today, reason: .landExpansion, ref: "land-\(next.size)")
            commitLedger(nextLedger)
            replace(world: try world.expanded())
            save()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    // MARK: - Enforcement

    /// Pay grit to open blocked apps for 15 minutes. Logged as a social-media slip.
    func buyUnblock() -> Bool {
        do {
            commitLedger(try state.ledger.spending(RewardRules.unblockGritCost, day: today, reason: .unblock, ref: "unblock"))
            var s = settings
            s.unblockUntil = Date.now.addingTimeInterval(TimeInterval(RewardRules.unblockMinutes * 60))
            update(settings: s)
            if let social = habits.first(where: { $0.id == "no-social-media" }) { log(.slipped, habitID: social.id) }
            return true
        } catch {
            errorMessage = Self.describe(error)
            return false
        }
    }

    // MARK: - When/where plans

    func setPlan(_ plan: HabitPlan?, habitID: String) {
        var s = settings
        s.habitPlans[habitID] = (plan?.time == nil && plan?.place == nil) ? nil : plan
        update(settings: s)
    }

    func reminders(now: Date = .now) -> [Reminder] {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        return ReminderPlanner.plan(day: today, now: ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0),
                                    habits: habits, plans: settings.habitPlans, index: index, gate: settings.gate,
                                    streakDays: streak.current, timeZone: timeZone)
    }

    // MARK: - Helpers

    func commitLedger(_ next: GritLedger) {
        persistLedgerTail(from: state.ledger, to: next)
        setState(MasteryState(habits: state.habits, completions: state.completions, ledger: next,
                              startDay: state.startDay, strictStreak: state.strictStreak, timeZone: timeZone))
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case LedgerError.insufficientGrit(let needed, let balance): return "Need \(needed) grit, you have \(balance)."
        case WorldError.levelTooLow(let required): return "Unlocks at level \(required)."
        case WorldError.occupied: return "That tile is taken."
        case WorldError.outOfBounds: return "Outside your land. Expand it in the shop."
        case WorldError.notOwned: return "Buy it in the shop first."
        case WorldError.maxLand: return "Your land is at full size."
        default: return error.localizedDescription
        }
    }
}
