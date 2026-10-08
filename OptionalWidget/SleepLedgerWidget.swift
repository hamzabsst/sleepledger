import SwiftUI
import WidgetKit

struct SleepEntry: TimelineEntry {
    var date: Date
    var duration: String
    var wake: Date?
    var origin: String
}
struct SleepProvider: TimelineProvider {
    func placeholder(in context: Context) -> SleepEntry { SleepEntry(date: .now, duration: "7h 45m", wake: .now, origin: "manual") }
    func getSnapshot(in context: Context, completion: @escaping (SleepEntry) -> Void) { completion(context.isPreview ? placeholder(in: context) : read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(3600))))
    }
    private func read() -> SleepEntry {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SleepLedgerAppGroup") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              let data = try? Data(contentsOf: container.appendingPathComponent("last-night.json")),
              let object = try? JSONSerialization.jsonObject(with: data), let values = object as? [String: String] else {
            return SleepEntry(date: .now, duration: "Open SleepLedger", wake: nil, origin: "")
        }
        return SleepEntry(date: .now, duration: values["duration"] ?? "—", wake: values["wake"].flatMap { ISO8601DateFormatter().date(from: $0) }, origin: values["origin"] ?? "")
    }
}
struct SleepWidgetView: View {
    let entry: SleepEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("SleepLedger", systemImage: "moon.stars.fill").font(.caption).foregroundStyle(.indigo)
            Text(entry.duration).font(.title2.bold()).minimumScaleFactor(0.6)
            if let wake = entry.wake { Text(wake, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(.secondary) }
            Text(entry.origin.capitalized).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color(.systemBackground) }
            .widgetURL(URL(string: "sleepledger://open"))
            .privacySensitive()
    }
}
@main struct SleepLedgerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SleepLedgerLastNight", provider: SleepProvider()) { SleepWidgetView(entry: $0) }
            .configurationDisplayName("Most recent night")
            .description("Your latest completed night, with its date and source label.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
