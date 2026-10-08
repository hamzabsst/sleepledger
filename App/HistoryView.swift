import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var adding = false
    var body: some View {
        NavigationStack {
            List {
                if store.sessions.isEmpty { ContentUnavailableView("Your first night starts here", systemImage: "moon", description: Text("Start a timer or add a past session.")) }
                ForEach(store.sessions) { record in
                    NavigationLink { SessionDetail(id: record.id) } label: { SessionLabel(record: record) }
                }
            }.navigationTitle("History")
                .toolbar { Button("Add session", systemImage: "plus") { adding = true } }
                .sheet(isPresented: $adding) { SessionEditor() }
        }
    }
}
struct SessionDetail: View {
    let id: UUID
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var editing = false
    @State private var deleting = false
    @State private var retrying = false
    @State private var showIllustration = false
    var record: SleepRecord? { store.sessions.first { $0.id == id } }
    var body: some View {
        Group {
            if let r = record {
                List {
                    Section { SessionLabel(record: r)
                        LabeledContent("Source", value: r.source)
                        LabeledContent("Recorded timezone", value: r.timeZoneID)
                        if !r.tags.isEmpty { Text(r.tags.joined(separator: " · ")) }
                    }
                    Section("Sleep stages") {
                        if !r.stages.isEmpty {
                            Text("Imported classifications from \(r.source). Device classifications are estimates, not a clinical measurement.").font(.footnote).foregroundStyle(.secondary)
                            ForEach(SleepStage.allCases, id: \.self) { stage in
                                let intervals = r.stages.filter { $0.stage == stage }.map { DateInterval(start: $0.start, end: $0.end) }
                                if !intervals.isEmpty { LabeledContent(stage.title, value: (Analysis.unionDuration(intervals) / 3600).sleepDuration) }
                            }
                            Text("In-bed and unspecified-asleep summaries can overlap detailed stages. Do not add their totals together.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("No stage data. Bedtime and wake time cannot tell us how much deep or REM sleep you had.")
                            Toggle("Show illustrative stage estimate", isOn: $showIllustration)
                            if showIllustration {
                                Text("Illustration only — fixed proportions, no personal accuracy. Never saved or sent to Health.").font(.caption).foregroundStyle(.orange)
                                ForEach(Analysis.illustrativeStages(hours: r.duration / 3600), id: \.0) { item in LabeledContent(item.0, value: item.1.sleepDuration) }
                            }
                        }
                    }
                    if r.origin == .manual && r.end != nil && r.stages.isEmpty {
                        Section("Apple Health through Shortcuts") {
                            Text("Exports this reported interval as In Bed. Build ‘SleepLedger Write Health’ using the included guide first.").font(.footnote)
                            if let status = store.receiptStatus(r) {
                                Text(status == "pending" ? "Pending or interrupted. Check Health before retrying." : "Shortcut reported completion. Verify in Health.")
                                if status == "pending" { Button("I checked Health: no matching record") { retrying = true } }
                            } else {
                                Button("Send interval to Health") {
                                    store.perform { let url = try store.healthURL(r); openURL(url) { accepted in if !accepted { store.message = "Shortcut could not open. The pending receipt remains so an accidental retry cannot duplicate a write." } } }
                                }
                            }
                        }
                    }
                    Section {
                        Button("Edit session") { editing = true }
                        Button("Delete session", role: .destructive) { deleting = true }
                    }
                }.navigationTitle(r.isNap ? "Nap" : "Sleep session")
                    .sheet(isPresented: $editing) { SessionEditor(record: r) }
                    .confirmationDialog("Delete this local session? Health records are managed separately.", isPresented: $deleting, titleVisibility: .visible) { Button("Delete session", role: .destructive) { if store.delete(r) { dismiss() } } }
                    .confirmationDialog("Only retry after checking Health contains no matching In Bed record. An interrupted Shortcut may already have written it.", isPresented: $retrying, titleVisibility: .visible) { Button("Clear pending transfer") { store.clearPendingReceipt(r) } }
            } else { ContentUnavailableView("Session removed", systemImage: "moon") }
        }
    }
}
