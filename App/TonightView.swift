import SwiftUI

struct TonightView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var adding = false
    var last: SleepRecord? { store.sessions.first { $0.end != nil && !$0.isNap } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(store.active == nil ? "A little more rest.\nA clearer tomorrow." : "Rest is in progress.").font(.largeTitle.weight(.bold)).tracking(-1)
                    ZStack {
                        Circle().stroke(.indigo.opacity(0.1), lineWidth: 16)
                        Circle().trim(from: 0, to: min(1, (last?.duration ?? 0) / (store.settings.goalHours * 3600)))
                            .stroke(.indigo.gradient, style: StrokeStyle(lineWidth: 16, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 8) {
                            Image(systemName: store.active == nil ? "moon.zzz.fill" : "moon.stars.fill").font(.title).foregroundStyle(.indigo)
                            if let active = store.active {
                                TimelineView(.periodic(from: .now, by: 60)) { context in
                                    Text((max(0, context.date.timeIntervalSince(active.start)) / 3600).sleepDuration).font(.largeTitle.bold()).monospacedDigit()
                                }
                                Text("Elapsed · not measured sleep").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(last.map { ($0.duration / 3600).sleepDuration } ?? "Ready for bed").font(.title.bold()).monospacedDigit()
                                Text(last == nil ? "Start your first session" : "Most recent night").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.frame(width: 250, height: 250).frame(maxWidth: .infinity).padding(.vertical, 8)
                    Button { store.active == nil ? store.start() : store.stop() } label: {
                        Label(store.active == nil ? "Start sleep" : "Stop sleep", systemImage: store.active == nil ? "moon.fill" : "sun.max.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    if let active = store.active, let suggested = Analysis.suggestedWake(start: active.start, records: store.sessions) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Forgot to stop?").font(.headline)
                            Text("Your usual wake time suggests \(suggested.formatted(date: .abbreviated, time: .shortened)). Confirm or adjust it before saving.").font(.subheadline)
                            Button("Review suggested wake time") {
                                var record = active; record.end = suggested; record.origin = .estimated; store.reviewStop = record
                            }.buttonStyle(.bordered)
                        }.padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }
                    HStack {
                        Metric(title: "Your goal", value: store.settings.goalHours.sleepDuration)
                        Metric(title: "7-day average", value: Analysis.average(Analysis.window(store.sessions, days: 7).map(\.hours))?.sleepDuration ?? "—")
                    }
                    Button("Add a forgotten session", systemImage: "plus.circle") { adding = true }
                    Text("Your journal stays on this iPhone. A timer records the interval you report; it does not detect sleep onset or awakenings.").font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }.navigationTitle("SleepLedger").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $adding) { SessionEditor() }
        }
    }
}
