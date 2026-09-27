//
//  PlayHistory.swift
//  NOVA
//

import Foundation
import Observation

/// Which days the reader finished a round. Feeds the week strip and the streak.
///
/// Only a finished round counts. Opening the app, or reading without playing, does not —
/// a streak that fills in by itself is the dishonest kind, and the product principles say
/// progress is only what the reader actually did.
@Observable
final class PlayHistory {
    struct Day: Equatable, Identifiable {
        let date: Date
        let played: Bool
        let isToday: Bool

        var id: Date { date }
    }

    private static let storageKey = "playedDays"

    private(set) var playedDays: Set<String>

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        self.playedDays = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
    }

    func record(_ date: Date = .now) {
        let key = dayKey(for: date)
        guard !playedDays.contains(key) else { return }
        playedDays.insert(key)
        defaults.set(playedDays.sorted(), forKey: Self.storageKey)
    }

    func hasPlayed(on date: Date) -> Bool {
        playedDays.contains(dayKey(for: date))
    }

    /// The seven days ending today, oldest first.
    func week(endingOn today: Date = .now) -> [Day] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: start).map { date in
                Day(date: date, played: hasPlayed(on: date), isToday: back == 0)
            }
        }
    }

    /// Consecutive days played, counting back from today — or from yesterday when today's
    /// round isn't done yet, so the streak doesn't read as broken first thing in the morning.
    func streak(endingOn today: Date = .now) -> Int {
        var day = calendar.startOfDay(for: today)
        if !hasPlayed(on: day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }

        var count = 0
        while hasPlayed(on: day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }

    /// A calendar day in the reader's own time zone, so a round finished at 11 pm counts
    /// for the day they played it and not for UTC's.
    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
