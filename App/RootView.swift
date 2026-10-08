import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: LedgerStore
    var body: some View {
        TabView {
            TonightView().tabItem { Label("Tonight", systemImage: "moon.stars") }
            HistoryView().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            TrendsView().tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(.indigo)
        .alert("SleepLedger", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .sheet(item: $store.reviewStop) { record in SessionEditor(record: record, reviewingStop: true) }
        .sheet(isPresented: Binding(get: { store.incoming != nil }, set: { if !$0 { store.incoming = nil } })) { ImportPreview() }
    }
}
extension Double {
    var sleepDuration: String {
        let minutes = Int((self * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    var clockText: String {
        let minutes = Int(self.rounded()) % 1440
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
struct Metric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct SessionLabel: View {
    let record: SleepRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.end ?? record.start, format: .dateTime.month(.abbreviated).day()).font(.headline)
                Spacer()
                Text(record.end == nil ? "Running" : (record.duration / 3600).sleepDuration).monospacedDigit().bold()
            }
            Text("\(record.start.formatted(date: .omitted, time: .shortened)) → \(record.end?.formatted(date: .omitted, time: .shortened) ?? "now")").font(.subheadline)
            HStack {
                Text(record.origin.rawValue.capitalized + (record.edited ? " · edited" : ""))
                if record.isNap { Text("Nap") }
                if let quality = record.quality { Text("Quality \(quality)/5") }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
