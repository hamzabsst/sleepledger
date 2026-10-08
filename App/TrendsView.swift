import SwiftUI
import Charts

struct StepPair: Identifiable {
    var day: Date
    var steps: Int
    var hours: Double
    var id: Date { day }
}
struct TrendsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var period = 7
    @State private var metric = "Duration"
    @State private var compareSteps = false
    var days: [DailySleep] { Analysis.window(store.sessions, days: period) }
    var records: [SleepRecord] { days.flatMap(\.records) }
    var mains: [SleepRecord] { days.compactMap(\.main) }
    var stepPairs: [StepPair] {
        days.compactMap { day in
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day.day),
                  let steps = store.steps.first(where: { Calendar.current.isDate($0.day, inSameDayAs: previous) }),
                  let main = day.main else { return nil }
            return StepPair(day: day.day, steps: steps.count, hours: main.duration / 3600)
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Window", selection: $period) { Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented)
                    if days.isEmpty { ContentUnavailableView("No completed sessions", systemImage: "chart.bar", description: Text("Add a night to begin.")) }
                    else {
                        HStack {
                            Metric(title: "Average per logged day", value: Analysis.average(days.map(\.hours))?.sleepDuration ?? "—")
                            Metric(title: "Goal deficit", value: Analysis.debt(days, goal: store.settings.goalHours).sleepDuration)
                        }.listRowInsets(EdgeInsets())
                        LabeledContent("Logged wake dates", value: "\(days.count) of \(period)")
                        LabeledContent("Average bedtime", value: Analysis.circularMean(mains.map { Analysis.minutes($0.start) })?.clockText ?? "—")
                        LabeledContent("Average wake time", value: Analysis.circularMean(mains.compactMap(\.end).map { Analysis.minutes($0) })?.clockText ?? "—")
                        LabeledContent("Bedtime variation", value: Analysis.variation(records).map { "\(Int($0.rounded())) min" } ?? "Need 2 nights")
                    }
                } footer: {
                    Text("Manual and in-bed-only entries are reported intervals, not measured sleep. Detailed imports use sleep-classified stage time. Averages use logged wake dates, including naps. Missing days are unknown. Goal deficit sums shortfalls on logged days; it is a planning measure, not physiological sleep debt. Bedtime variation is the circular RMS deviation of the main session per day. Times use your current timezone.")
                }
                if !days.isEmpty {
                    Section("Trend") {
                        Picker("Metric", selection: $metric) { Text("Duration").tag("Duration"); Text("Bedtime").tag("Bedtime"); Text("Wake").tag("Wake") }.pickerStyle(.segmented)
                        trendChart.frame(height: 220).padding(.vertical)
                        if let best = mains.max(by: { $0.duration < $1.duration }), let worst = mains.min(by: { $0.duration < $1.duration }) {
                            Text("Longest night: \(best.end!.formatted(date: .abbreviated, time: .omitted)), \((best.duration / 3600).sleepDuration).")
                            Text("Shortest night: \(worst.end!.formatted(date: .abbreviated, time: .omitted)), \((worst.duration / 3600).sleepDuration).")
                        }
                        if let best = mains.filter({ $0.quality != nil }).max(by: { $0.quality! < $1.quality! }),
                           let worst = mains.filter({ $0.quality != nil }).min(by: { $0.quality! < $1.quality! }) {
                            Text("Highest rated: \(best.end!.formatted(date: .abbreviated, time: .omitted)), \(best.quality!)/5. Lowest rated: \(worst.end!.formatted(date: .abbreviated, time: .omitted)), \(worst.quality!)/5.")
                        }
                        Text("Includes \(records.filter { $0.origin == .estimated }.count) estimated records. More time in bed does not always mean better sleep.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Your usual schedule") {
                    scheduleRow("Weekdays", weekend: false)
                    scheduleRow("Weekends", weekend: true)
                    Text("Learns from the last 60 days; needs 3 main sessions in each group. Grouped by wake date. Estimates and naps are excluded.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Weekly summary") {
                    Text(weeklySummary)
                    let insights = Analysis.tagInsights(store.sessions)
                    if insights.isEmpty { Text("Rate at least 3 tagged and 3 untagged nights to compare a tag. These comparisons are descriptive.").foregroundStyle(.secondary) }
                    ForEach(insights, id: \.self) { Text($0) }
                }
                Section("Steps and the following night") {
                    Toggle("Compare imported daily steps", isOn: $compareSteps)
                    if compareSteps {
                        if stepPairs.isEmpty { Text("Import daily totals through Shortcuts or JSON. Pairing uses steps on the calendar day before each wake date.").foregroundStyle(.secondary) }
                        else {
                            Chart(stepPairs) { pair in PointMark(x: .value("Previous-day steps", pair.steps), y: .value("Night hours", pair.hours)).foregroundStyle(.indigo) }.frame(height: 200)
                            Text("\(stepPairs.count) pairs. A visual association cannot establish that steps changed your sleep. Use one consistent step source; raw multi-source counts are not Health’s deduplicated total.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.navigationTitle("Trends")
        }
    }
    @ViewBuilder private var trendChart: some View {
        if metric == "Duration" {
            Chart {
                ForEach(days) { day in BarMark(x: .value("Wake date", day.day, unit: .day), y: .value("Hours", day.hours)).foregroundStyle(.indigo.gradient) }
                RuleMark(y: .value("Goal", store.settings.goalHours)).lineStyle(StrokeStyle(dash: [5])).foregroundStyle(.secondary)
            }.chartYAxisLabel("Hours")
        } else {
            Chart(mains) { record in
                let date = metric == "Bedtime" ? record.start : record.end!
                let minute = Analysis.minutes(date)
                let adjusted = metric == "Bedtime" && minute < 720 ? minute + 1440 : minute
                PointMark(x: .value("Wake date", record.end!, unit: .day), y: .value("Clock minutes", adjusted)).foregroundStyle(record.origin == .estimated ? .orange : .indigo)
            }.chartYAxis {
                AxisMarks { value in
                    AxisGridLine(); AxisTick()
                    AxisValueLabel { if let minute = value.as(Double.self) { Text(minute.clockText) } }
                }
            }.chartYAxisLabel("Local time")
        }
    }
    @ViewBuilder private func scheduleRow(_ title: String, weekend: Bool) -> some View {
        if let schedule = Analysis.schedule(store.sessions, weekend: weekend) {
            LabeledContent(title, value: "\(schedule.bedtimeMinutes.clockText) → \(schedule.wakeMinutes.clockText) · \(schedule.count) nights")
        } else { LabeledContent(title, value: "Need 3 nights") }
    }
    private var weeklySummary: String {
        let current = Analysis.window(store.sessions, days: 7)
        let previousNow = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let previous = Analysis.window(store.sessions, days: 7, now: previousNow)
        guard let average = Analysis.average(current.map(\.hours)) else { return "Log a night for your first weekly summary." }
        var result = "Last 7 days: \(average.sleepDuration) average across \(current.count) logged wake dates."
        if let old = Analysis.average(previous.map(\.hours)) { result += " \(String(format: "%+.0f", (average - old) * 60)) minutes versus the previous week (\(previous.count) logged dates)." }
        return result
    }
}
