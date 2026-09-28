//
//  ReminderScheduler.swift
//  NOVA
//

import Foundation
import Observation
import UserNotifications

/// Which days get a reminder. Pure, so the rules are tested without a notification centre.
///
/// One non-repeating reminder per day for a week, rather than one repeating trigger: a
/// repeating trigger can't skip a single day, and the reminder must not arrive on a day the
/// round is already done — a nudge for work already finished is noise. The week is topped
/// back up on every launch.
enum ReminderPlan {
    static let prefix = "reminder-"

    static func identifier(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "\(prefix)%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func schedule(
        now: Date,
        hour: Int,
        minute: Int,
        todayDone: Bool,
        days: Int = 7,
        calendar: Calendar = .current
    ) -> [(id: String, fireDate: Date)] {
        let today = calendar.startOfDay(for: now)
        var plan: [(id: String, fireDate: Date)] = []

        // Two spare days: today can be skipped (passed, or done) and the week still has seven.
        for offset in 0..<(days + 2) where plan.count < days {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                fire > now,
                !(offset == 0 && todayDone)
            else { continue }
            plan.append((identifier(for: day, calendar: calendar), fire))
        }
        return plan
    }
}

/// The slice of `UNUserNotificationCenter` the scheduler uses, so tests can fake it.
protocol NotificationCentre: Sendable {
    func requestAuthorization() async -> Bool
    func pendingIdentifiers() async -> [String]
    func add(id: String, fireDate: Date, title: String, body: String) async
    func remove(ids: [String])
}

/// The real centre. Local notifications only — no server, no push certificate, nothing
/// that costs anything to run.
struct SystemNotificationCentre: NotificationCentre {
    private var centre: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pendingIdentifiers() async -> [String] {
        await centre.pendingNotificationRequests().map(\.identifier)
    }

    func add(id: String, fireDate: Date, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        try? await centre.add(request)
    }

    func remove(ids: [String]) {
        centre.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

/// The daily reminder: off by default, one a day at the reader's chosen time, never on a
/// day already played. Offered after the first round and switchable in Profile; it asks
/// for notification permission only when the reader turns it on.
@Observable
final class ReminderScheduler {
    private enum Key {
        static let enabled = "reminderEnabled"
        static let hour = "reminderHour"
        static let minute = "reminderMinute"
    }

    private(set) var isEnabled: Bool
    private(set) var hour: Int
    private(set) var minute: Int
    /// Set when the reader said no to the system prompt, so Profile can explain why the
    /// switch won't stay on and point to Settings.
    private(set) var wasDenied = false

    private let centre: NotificationCentre
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var language: ContentLanguage = .english
    private var todayDone = false

    init(
        centre: NotificationCentre = SystemNotificationCentre(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.centre = centre
        self.defaults = defaults
        self.calendar = calendar
        isEnabled = defaults.bool(forKey: Key.enabled)
        hour = defaults.object(forKey: Key.hour) as? Int ?? 8
        minute = defaults.object(forKey: Key.minute) as? Int ?? 0
    }

    func enable() async {
        guard await centre.requestAuthorization() else {
            wasDenied = true
            setEnabled(false)
            return
        }
        wasDenied = false
        setEnabled(true)
        await reschedule()
    }

    func disable() async {
        setEnabled(false)
        await clear()
    }

    func setTime(hour: Int, minute: Int) async {
        self.hour = hour
        self.minute = minute
        defaults.set(hour, forKey: Key.hour)
        defaults.set(minute, forKey: Key.minute)
        if isEnabled { await reschedule() }
    }

    /// On launch and whenever the news language changes: tops the week back up.
    func refresh(todayDone: Bool, language: ContentLanguage) async {
        self.todayDone = todayDone
        self.language = language
        if isEnabled { await reschedule() }
    }

    /// Called when a round is recorded. Only today's request goes; the rest of the week stays.
    func markTodayDone() async {
        todayDone = true
        centre.remove(ids: [ReminderPlan.identifier(for: .now, calendar: calendar)])
    }

    /// In the news language rather than the UI language: a reader who chose Hindi news on
    /// an English phone asked to be spoken to in Hindi.
    static func copy(for language: ContentLanguage) -> (title: String, body: String) {
        switch language {
        case .english: ("Today's five stories are ready", "Read them, then answer a question on each.")
        case .hindi: ("आज की पाँच खबरें तैयार हैं", "पढ़िए, फिर हर खबर पर एक सवाल का जवाब दीजिए।")
        }
    }

    // MARK: - Private

    private func setEnabled(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: Key.enabled)
    }

    private func clear() async {
        let ours = await centre.pendingIdentifiers().filter { $0.hasPrefix(ReminderPlan.prefix) }
        centre.remove(ids: ours)
    }

    private func reschedule() async {
        await clear()
        let copy = Self.copy(for: language)
        let plan = ReminderPlan.schedule(
            now: .now, hour: hour, minute: minute, todayDone: todayDone, calendar: calendar
        )
        for entry in plan {
            await centre.add(id: entry.id, fireDate: entry.fireDate, title: copy.title, body: copy.body)
        }
    }
}
