import Foundation
import Testing
@testable import MasteryCore

@Suite struct LessonTests {
    private let day = DayKey("2026-10-20")!
    private let lessons = [
        Lesson(id: "a1", habitID: "sleep", text: "Same bedtime", source: "yt:AAA", locator: "01:05"),
        Lesson(id: "a2", habitID: "sleep", text: "Cold room", source: "yt:AAA", locator: "02:00"),
        Lesson(id: "b1", habitID: "no-nicotine", text: "Bin the tins", source: "yt:BBB", locator: "1:01:30"),
        Lesson(id: "c1", habitID: "morning-routine", text: "Wake earlier", source: "book:bennett", locator: "¶13"),
    ]
    private let order = ["sleep", "no-nicotine", "morning-routine"]

    @Test func firstLessonsInterleaveHabitsInFocusOrder() {
        #expect(LessonPlanner.pick(lessons, records: [:], habitOrder: order, today: day)?.id == "a1")
        let keptA1 = LessonPlanner.answering([:], lessonID: "a1", kept: true, on: day.adding(days: -1))
        #expect(LessonPlanner.pick(lessons, records: keptA1, habitOrder: order, today: day)?.id == "b1")
    }

    @Test func unansweredLessonStaysUntilAnswered() {
        #expect(LessonPlanner.pick(lessons, records: [:], habitOrder: order, today: day.adding(days: 5))?.id == "a1")
    }

    @Test func answeredLessonStaysTodaysLessonAllDay() {
        let records = LessonPlanner.answering([:], lessonID: "a1", kept: true, on: day)
        #expect(LessonPlanner.pick(lessons, records: records, habitOrder: order, today: day)?.id == "a1")
    }

    @Test func missedLessonComesBackAfterThreeDays() {
        let missed = LessonPlanner.answering([:], lessonID: "a1", kept: false, on: day)
        #expect(missed["a1"]?.status == .learning)
        #expect(missed["a1"]?.misses == 1)
        #expect(LessonPlanner.pick(lessons, records: missed, habitOrder: order, today: day.adding(days: 1))?.id == "b1")
        #expect(LessonPlanner.pick(lessons, records: missed, habitOrder: order, today: day.adding(days: 3))?.id == "a1")
    }

    @Test func keptLessonsNeverReturnAndAllKeptMeansNoLesson() {
        var records: [String: LessonRecord] = [:]
        for (offset, lesson) in lessons.enumerated() {
            records = LessonPlanner.answering(records, lessonID: lesson.id, kept: true, on: day.adding(days: -10 + offset))
        }
        #expect(LessonPlanner.pick(lessons, records: records, habitOrder: order, today: day) == nil)
    }

    @Test func youTubeLessonsLinkToTheMoment() {
        #expect(lessons[0].videoURL?.absoluteString == "https://www.youtube.com/watch?v=AAA&t=65s")
        #expect(lessons[2].videoURL?.absoluteString == "https://www.youtube.com/watch?v=BBB&t=3690s")
        #expect(lessons[3].videoURL == nil)
    }

    @Test func planDecodesLessonsAndToleratesTheirAbsence() throws {
        let withLessons = #"{"format":"conor-mastery-plan","version":1,"generated_at":"x","habits":[],"lessons":[{"id":"a","habit":"sleep","text":"t","source":"yt:A","locator":"00:10"}]}"#
        let without = #"{"format":"conor-mastery-plan","version":1,"generated_at":"x","habits":[]}"#
        #expect(try JSONDecoder().decode(MasteryPlan.self, from: Data(withLessons.utf8)).lessons.first?.habitID == "sleep")
        #expect(try JSONDecoder().decode(MasteryPlan.self, from: Data(without.utf8)).lessons.isEmpty)
    }
}
