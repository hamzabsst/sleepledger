import SwiftUI

struct SessionEditor: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    private let original: SleepRecord?
    private let reviewingStop: Bool
    @State private var start: Date
    @State private var end: Date
    @State private var completed: Bool
    @State private var nap: Bool
    @State private var quality: Int
    @State private var tags: Set<String>
    @State private var clearStages = false
    @State private var saveError: String?
    private let choices = ["caffeine", "alcohol", "stress", "late screen time", "exercise"]
    init(record: SleepRecord? = nil, reviewingStop: Bool = false) {
        original = record; self.reviewingStop = reviewingStop
        _start = State(initialValue: record?.start ?? Date().addingTimeInterval(-8 * 3600))
        _end = State(initialValue: record?.end ?? Date())
        _completed = State(initialValue: record == nil || record?.end != nil)
        _nap = State(initialValue: record?.isNap ?? false)
        _quality = State(initialValue: record?.quality ?? 0)
        _tags = State(initialValue: Set(record?.tags ?? []))
    }
    var timesChanged: Bool { original.map { $0.start != start || $0.end != (completed ? end : nil) } ?? false }
    var stageWarning: Bool { !(original?.stages.isEmpty ?? true) && timesChanged }
    var body: some View {
        NavigationStack {
            Form {
                Section("Reported interval") {
                    DatePicker("Bedtime", selection: $start, in: ...Date())
                    Toggle("Completed session", isOn: $completed)
                    if completed { DatePicker("Wake time", selection: $end, in: ...Date()) }
                    Toggle("This was a nap", isOn: $nap)
                    if completed && end > start { LabeledContent("Elapsed interval", value: (end.timeIntervalSince(start) / 3600).sleepDuration) }
                }
                Section("How did it feel?") {
                    Picker("Morning quality", selection: $quality) {
                        Text("Not rated").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0) / 5").tag($0) }
                    }
                    ForEach(Array(Set(choices).union(tags)).sorted(), id: \.self) { tag in
                        Toggle(tag.capitalized, isOn: Binding(get: { tags.contains(tag) }, set: { if $0 { tags.insert(tag) } else { tags.remove(tag) } }))
                    }
                }
                if let original {
                    Section("Provenance") {
                        Text(original.origin == .estimated ? "Estimated wake time — saving confirms this suggestion. The record keeps its Estimated label." : "\(original.origin.rawValue.capitalized) record. Edits retain its original source and show an edited label.")
                        if stageWarning {
                            Toggle("Remove imported stages for this changed interval", isOn: $clearStages)
                            Text("Stage timings no longer match. Export a backup first if you want to retain them.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.navigationTitle(reviewingStop ? "Confirm wake time" : original == nil ? "Add sleep" : "Edit sleep")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled((completed && end <= start) || (stageWarning && !clearStages)) }
                }
        }
        .alert("Could not save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) { Button("OK") { saveError = nil } } message: { Text(saveError ?? "") }
    }
    private func save() {
        var r = original ?? SleepRecord(start: start)
        r.start = start; r.end = completed ? end : nil; r.isNap = nap; r.quality = quality == 0 ? nil : quality; r.tags = tags.sorted()
        if original != nil && !reviewingStop { r.edited = true }
        if stageWarning { r.stages = [] }
        if store.update(r) { dismiss() } else { saveError = store.message; store.message = nil }
    }
}
