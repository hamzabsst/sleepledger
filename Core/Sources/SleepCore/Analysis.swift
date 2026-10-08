import Foundation

public struct DailySleep: Identifiable {
    public var day: Date
    public var records: [SleepRecord]
    public var id: Date { day }
    public var hours: Double { records.reduce(0) { $0 + $1.duration } / 3600 }
    public var main: SleepRecord? { records.filter { !$0.isNap }.max { $0.duration < $1.duration } }
}
public struct Schedule {
    public var bedtimeMinutes: Double
    public var wakeMinutes: Double
    public var count: Int
}
public enum Analysis {
    public static func unionDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end { current = DateInterval(start: current.start, end: max(current.end, interval.end)) }
            else { total += current.duration; current = interval }
        }
        return total + current.duration
    }
    public static func days(_ records: [SleepRecord], calendar: Calendar = .current) -> [DailySleep] {
        let completed = records.filter { $0.end != nil }
        return Dictionary(grouping: completed, by: { calendar.startOfDay(for: $0.end!) })
            .map { DailySleep(day: $0.key, records: $0.value) }.sorted { $0.day < $1.day }
    }
    /// Last N completed calendar days, including today, attributed to wake date. Missing days remain unknown.
    public static func window(_ records: [SleepRecord], days count: Int, now: Date = Date(), calendar: Calendar = .current) -> [DailySleep] {
        let today = calendar.startOfDay(for: now)
        let lower = calendar.date(byAdding: .day, value: -(count - 1), to: today)!
        return days(records, calendar: calendar).filter { $0.day >= lower && $0.day <= today }
    }
    public static func average(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    public static func minutes(_ date: Date, calendar: Calendar = .current) -> Double {
        Double(calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date))
    }
    public static func circularMean(_ minutes: [Double]) -> Double? {
        guard !minutes.isEmpty else { return nil }
        let x = minutes.reduce(0) { $0 + cos($1 / 1440 * 2 * .pi) }
        let y = minutes.reduce(0) { $0 + sin($1 / 1440 * 2 * .pi) }
        guard hypot(x, y) / Double(minutes.count) > 0.1 else { return nil }
        return (atan2(y, x) / (2 * .pi) * 1440 + 1440).truncatingRemainder(dividingBy: 1440)
    }
    public static func clockDistance(_ a: Double, _ b: Double) -> Double { min(abs(a-b), 1440-abs(a-b)) }
    public static func variation(_ records: [SleepRecord], calendar: Calendar = .current) -> Double? {
        let times = days(records, calendar: calendar).compactMap(\.main).map { minutes($0.start, calendar: calendar) }
        guard times.count >= 2, let mean = circularMean(times) else { return nil }
        return sqrt(times.reduce(0) { $0 + pow(clockDistance($1, mean), 2) } / Double(times.count))
    }
    /// Use the longest non-nap per wake date; exclude estimates to avoid self-reinforcement.
    public static func schedule(_ records: [SleepRecord], weekend: Bool, now: Date = Date(), calendar: Calendar = .current) -> Schedule? {
        let samples = window(records.filter { $0.origin != .estimated }, days: 60, now: now, calendar: calendar)
            .compactMap(\.main).filter { calendar.isDateInWeekend($0.end!) == weekend }
        guard samples.count >= 3,
              let bed = circularMean(samples.map { minutes($0.start, calendar: calendar) }),
              let wake = circularMean(samples.map { minutes($0.end!, calendar: calendar) }) else { return nil }
        return Schedule(bedtimeMinutes: bed, wakeMinutes: wake, count: samples.count)
    }
    public static func suggestedWake(start: Date, records: [SleepRecord], now: Date = Date(), calendar: Calendar = .current) -> Date? {
        var candidates: [Date] = []
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start))!
            guard let schedule = schedule(records, weekend: calendar.isDateInWeekend(day), now: now, calendar: calendar) else { continue }
            let total = Int(schedule.wakeMinutes.rounded()) % 1440
            guard let wake = calendar.date(bySettingHour: total / 60, minute: total % 60, second: 0, of: day),
                  wake > start, wake <= now, (2 * 3600...16 * 3600).contains(wake.timeIntervalSince(start)) else { continue }
            candidates.append(wake)
        }
        return candidates.min()
    }
    /// Sum deficits on observed days. Surpluses do not erase earlier deficits; unknown days are excluded.
    public static func debt(_ days: [DailySleep], goal: Double) -> Double { days.reduce(0) { $0 + max(0, goal - $1.hours) } }
    public static func illustrativeStages(hours: Double) -> [(String, Double)] {
        [("Core (illustrative)", hours * 0.55), ("Deep (illustrative)", hours * 0.20), ("REM (illustrative)", hours * 0.25)]
    }
    public static func tagInsights(_ records: [SleepRecord]) -> [String] {
        let rated = records.filter { !$0.isNap && $0.end != nil && $0.quality != nil }
        let tags = Set(rated.flatMap(\.tags))
        return tags.sorted().compactMap { tag in
            let with = rated.filter { $0.tags.contains(tag) }.map { Double($0.quality!) }
            let without = rated.filter { !$0.tags.contains(tag) }.map { Double($0.quality!) }
            guard with.count >= 3, without.count >= 3 else { return nil }
            let delta = average(with)! - average(without)!
            return "\(tag): quality \(String(format: "%+.1f", delta))/5 versus untagged sessions (\(with.count) vs \(without.count)). Association, not causation."
        }
    }
}
