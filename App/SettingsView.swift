import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var importing = false
    @State private var paste = ""
    @State private var exportURL: URL?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your rhythm") {
                    Stepper("Sleep goal: \(String(format: "%.1f", store.settings.goalHours)) hours", value: $store.settings.goalHours, in: 4...12, step: 0.25)
                    Picker("Appearance", selection: $store.settings.appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                    Toggle("Bedtime reminder", isOn: $store.settings.reminderEnabled)
                    if store.settings.reminderEnabled {
                        DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                    Button("Save goal and reminder") { store.applySettings(); Task { await store.scheduleReminder() } }
                    Text("Reminders follow local device time. Focus settings can silence them. Save again after a timezone or daylight-saving change if needed.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Backup and export") {
                    Button("Prepare full JSON backup") { store.perform { exportURL = try store.export(backup: true) } }
                    Button("Prepare sessions CSV") { store.perform { exportURL = try store.export(backup: false) } }
                    if let exportURL { ShareLink(item: exportURL) { Label("Share \(exportURL.lastPathComponent)", systemImage: "square.and.arrow.up") } }
                    Text("JSON includes sessions, stages, steps and settings. CSV includes sessions and stages. Save a copy in Files before reinstalling. Backups contain personal data; store them somewhere private.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Import / restore") {
                    Button("Choose JSON or CSV file") { importing = true }
                    PasteButton(payloadType: String.self) { strings in paste = strings.joined(separator: "\n") }
                    TextEditor(text: $paste).frame(minHeight: 100).font(.caption.monospaced()).accessibilityLabel("JSON or CSV to import")
                    Button("Preview pasted data") { store.preview(Data(paste.utf8)) }.disabled(paste.isEmpty)
                    Text("Review before saving. Imports never overwrite an existing session or step day. Overlaps are skipped; edit/delete a conflicting local record first if you explicitly want to replace it.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Quick access") {
                    Text("Create ‘Start SleepLedger’ with URL sleepledger://start → Open URLs. Create ‘Stop SleepLedger’ with sleepledger://stop → Open URLs. Stop opens a wake-time review.")
                    Text("Add either Shortcut to your Home Screen, Shortcuts widget, or Action Button. Shortcuts may require unlocking the phone. See Docs/SHORTCUTS.md for Health and alarm automation recipes.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Local first") {
                    Text("No account, analytics, network client, HealthKit, or cloud database. Health access belongs to Shortcuts. Source timestamps are preserved in exports; trends display in your current timezone.")
                    Text("Version 1.0 · iOS 17+").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings")
                .onChange(of: store.settings) { _, _ in store.applySettings() }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .commaSeparatedText, .plainText, .data]) { result in
                    switch result { case .success(let url): store.loadFile(url); case .failure(let error): store.message = error.localizedDescription }
                }
        }
    }
    private var reminderTime: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: store.settings.reminderHour, minute: store.settings.reminderMinute, second: 0, of: Date()) ?? Date() }, set: {
            store.settings.reminderHour = Calendar.current.component(.hour, from: $0)
            store.settings.reminderMinute = Calendar.current.component(.minute, from: $0)
        })
    }
}
struct ImportPreview: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var restoreSettings = false
    @State private var importError: String?
    var body: some View {
        NavigationStack {
            List {
                if let incoming = store.incoming {
                    Section {
                        Text("\(incoming.sessions.count) sessions · \(incoming.steps.count) step days")
                        Text("New records are added. Duplicates and overlaps are skipped. Provenance in backups is retained; Health CSV always becomes Imported.").font(.footnote).foregroundStyle(.secondary)
                        if incoming.settings != nil { Toggle("Restore backup settings", isOn: $restoreSettings) }
                        if restoreSettings { Text("Reminder settings are restored, but tap Save goal and reminder afterward to schedule notifications.").font(.caption) }
                    }
                    Section("Sessions (first 100)") {
                        ForEach(Array(incoming.sessions.prefix(100).enumerated()), id: \.offset) { _, r in
                            VStack(alignment: .leading) {
                                SessionLabel(record: r)
                                Text(matchLabel(r)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.navigationTitle("Review import")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { store.incoming = nil; dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Import") { if !store.importPending(restoreSettings: restoreSettings) { importError = store.message; store.message = nil } } }
                }
        }
        .alert("Could not import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
    }
    private func matchLabel(_ r: SleepRecord) -> String {
        switch Transfer.match(r, existing: store.sessions) { case .new: return "New (batch conflicts checked on save)"; case .duplicate: return "Duplicate — will skip"; case .overlap: return "Overlaps local session — will skip" }
    }
}
