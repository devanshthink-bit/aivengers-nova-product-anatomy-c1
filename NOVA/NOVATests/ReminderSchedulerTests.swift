//
//  ReminderSchedulerTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Reminder plan")
struct ReminderPlanTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: hour, minute: minute))!
    }

    @Test("Seven reminders, starting today when the time is still ahead")
    func startsToday() {
        let plan = ReminderPlan.schedule(now: at(7), hour: 8, minute: 0, todayDone: false, calendar: calendar)

        #expect(plan.count == 7)
        #expect(plan.first?.id == "reminder-2026-09-28")
        #expect(plan.last?.id == "reminder-2026-10-04")
    }

    @Test("A time already past today starts tomorrow")
    func pastTimeStartsTomorrow() {
        let plan = ReminderPlan.schedule(now: at(9), hour: 8, minute: 0, todayDone: false, calendar: calendar)

        #expect(plan.first?.id == "reminder-2026-09-29")
        #expect(plan.count == 7)
    }

    @Test("Today is skipped once the round is done")
    func skipsDoneToday() {
        let plan = ReminderPlan.schedule(now: at(7), hour: 8, minute: 0, todayDone: true, calendar: calendar)

        #expect(plan.first?.id == "reminder-2026-09-29")
        #expect(plan.count == 7)
    }

    @Test("Each reminder fires at the chosen hour and minute")
    func fireTimes() {
        let plan = ReminderPlan.schedule(now: at(7), hour: 20, minute: 30, todayDone: false, calendar: calendar)

        #expect(plan.allSatisfy {
            let parts = calendar.dateComponents([.hour, .minute], from: $0.fireDate)
            return parts.hour == 20 && parts.minute == 30
        })
    }
}

@Suite("Reminder scheduler")
@MainActor
struct ReminderSchedulerTests {
    final class FakeCentre: NotificationCentre, @unchecked Sendable {
        var granted = true
        var pending: [String: Date] = [:]
        var titles: [String] = []

        func requestAuthorization() async -> Bool { granted }
        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func add(id: String, fireDate: Date, title: String, body: String) async {
            pending[id] = fireDate
            titles.append(title)
        }
        func remove(ids: [String]) { ids.forEach { pending[$0] = nil } }
    }

    private func defaults() -> UserDefaults {
        let name = "reminder-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Off by default, at eight in the morning")
    func defaultsOff() {
        let scheduler = ReminderScheduler(centre: FakeCentre(), defaults: defaults())

        #expect(scheduler.isEnabled == false)
        #expect(scheduler.hour == 8)
        #expect(scheduler.minute == 0)
    }

    @Test("Enabling asks permission and schedules the week")
    func enable() async {
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())

        await scheduler.enable()

        #expect(scheduler.isEnabled)
        #expect(centre.pending.count == 7)
    }

    @Test("A refused permission turns the switch back off and says so")
    func denied() async {
        let centre = FakeCentre()
        centre.granted = false
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())

        await scheduler.enable()

        #expect(scheduler.isEnabled == false)
        #expect(scheduler.wasDenied)
        #expect(centre.pending.isEmpty)
    }

    @Test("Finishing the round removes today's reminder only")
    func markTodayDoneRemovesToday() async {
        // 23:59 so "today" is still ahead whenever this runs. It is flaky in the one minute
        // before midnight, which is accepted rather than injecting a clock everywhere.
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())
        await scheduler.setTime(hour: 23, minute: 59)
        await scheduler.enable()
        let today = ReminderPlan.identifier(for: .now, calendar: .current)
        #expect(centre.pending[today] != nil)

        await scheduler.markTodayDone()

        #expect(centre.pending[today] == nil)
        #expect(centre.pending.count == 6)
    }

    @Test("Disabling clears everything it scheduled")
    func disable() async {
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())
        await scheduler.enable()

        await scheduler.disable()

        #expect(centre.pending.isEmpty)
        #expect(scheduler.isEnabled == false)
    }

    @Test("The reminder speaks the news language")
    func languageCopy() async {
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())
        await scheduler.refresh(todayDone: false, language: .hindi)

        await scheduler.enable()

        #expect(centre.titles.allSatisfy { $0 == ReminderScheduler.copy(for: .hindi).title })
    }

    @Test("Settings survive a relaunch")
    func persists() async {
        let store = defaults()
        let first = ReminderScheduler(centre: FakeCentre(), defaults: store)
        await first.setTime(hour: 21, minute: 15)
        await first.enable()

        let second = ReminderScheduler(centre: FakeCentre(), defaults: store)

        #expect(second.isEnabled)
        #expect(second.hour == 21)
        #expect(second.minute == 15)
    }
}
