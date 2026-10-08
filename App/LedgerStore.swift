import Foundation
import SwiftData
import SwiftUI
import UserNotifications

@MainActor final class LedgerStore: ObservableObject {
    let container: ModelContainer
    private let context: ModelContext
    @Published private(set) var sessions: [SleepRecord] = []
    @Published private(set) var steps: [StepDay] = []
    @Published var settings: LedgerSettings
    @Published var message: String?
    @Published var incoming: TransferEnvelope?
    @Published var reviewStop: SleepRecord?
    @Published var receiptRevision = 0
    private let settingsKey = "ledger.settings.v1"

    init() throws {
        let schema = Schema([SessionEntity.self, StepsEntity.self, WriteReceipt.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)])
        context = ModelContext(container); context.autosaveEnabled = false
        if let data = UserDefaults.standard.data(forKey: settingsKey) {
            settings = try Wire.decoder().decode(LedgerSettings.self, from: data)
        } else { settings = LedgerSettings() }
        try refresh()
    }
    var active: SleepRecord? { sessions.first { $0.end == nil } }
    func refresh() throws {
        sessions = try context.fetch(FetchDescriptor<SessionEntity>()).map { try $0.record() }.sorted { $0.start > $1.start }
        steps = try context.fetch(FetchDescriptor<StepsEntity>()).map { try $0.value() }.sorted { $0.day > $1.day }
        receiptRevision += 1
        WidgetPublisher.publish(sessions)
    }
    @discardableResult func perform(_ work: () throws -> Void) -> Bool {
        do { try work(); return true } catch { context.rollback(); message = error.localizedDescription; return false }
    }
    private func save() throws { try context.save(); try refresh() }
    func start() {
        guard active == nil else { message = "Sleep is already running."; return }
        perform { context.insert(try SessionEntity(SleepRecord(start: Date()))); try save() }
    }
    func stop() {
        guard var record = active else { message = "There is no active session."; return }
        record.end = Date()
        if record.end!.timeIntervalSince(record.start) > 48 * 3600 { reviewStop = record; return }
        if update(record) { message = "Session saved. You can add quality and tags in History." }
    }
    @discardableResult func update(_ record: SleepRecord) -> Bool {
        perform {
            try record.validate()
            let others = sessions.filter { $0.id != record.id }
            if record.end == nil && others.contains(where: { $0.end == nil }) { throw LedgerError.invalid("Only one active session is allowed.") }
            guard Transfer.match(record, existing: others) == .new else { throw LedgerError.invalid("This interval overlaps an existing session. Edit that session first.") }
            let entities = try context.fetch(FetchDescriptor<SessionEntity>())
            if let entity = entities.first(where: { $0.id == record.id }) { entity.payload = try Wire.encoder().encode(record) }
            else { context.insert(try SessionEntity(record)) }
            try save()
        }
    }
    @discardableResult func delete(_ record: SleepRecord) -> Bool {
        perform {
            for entity in try context.fetch(FetchDescriptor<SessionEntity>()) where entity.id == record.id { context.delete(entity) }
            try save()
        }
    }
    func preview(_ data: Data) { perform { incoming = try Transfer.decode(data) } }
    @discardableResult func importPending(restoreSettings: Bool) -> Bool {
        guard let incoming else { return false }
        return perform {
            var existing = sessions, inserted = 0, duplicates = 0, conflicts = 0
            for record in incoming.sessions {
                switch Transfer.match(record, existing: existing) {
                case .duplicate: duplicates += 1
                case .overlap: conflicts += 1
                case .new:
                    if record.end == nil && existing.contains(where: { $0.end == nil }) { conflicts += 1; continue }
                    context.insert(try SessionEntity(record)); existing.append(record); inserted += 1
                }
            }
            var knownDays = Set(steps.map { Calendar.current.startOfDay(for: $0.day) }), stepConflicts = 0, addedSteps = 0
            for day in incoming.steps {
                if !knownDays.insert(Calendar.current.startOfDay(for: day.day)).inserted { stepConflicts += 1; continue }
                context.insert(try StepsEntity(day)); addedSteps += 1
            }
            try save()
            if restoreSettings, let restored = incoming.settings {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bedtime"])
                settings = restored; try persistSettings()
            }
            self.incoming = nil
            message = "Added \(inserted) sessions and \(addedSteps) step days. Skipped \(duplicates) duplicates, \(conflicts) overlapping sessions, \(stepConflicts) existing step days. Existing records were preserved."
        }
    }
    func persistSettings() throws {
        try settings.validate()
        UserDefaults.standard.set(try Wire.encoder().encode(settings), forKey: settingsKey)
    }
    func applySettings() { perform { try persistSettings() } }
    func export(backup: Bool) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SleepLedger-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(backup ? "SleepLedger-backup.json" : "SleepLedger-sessions.csv")
        let data = backup ? try Wire.encoder().encode(TransferEnvelope(sessions: sessions, steps: steps, settings: settings)) : Data(try Transfer.exportCSV(sessions).utf8)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    func loadFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        perform {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= Transfer.maxBytes else { throw LedgerError.invalid("File exceeds 8 MB.") }
            incoming = try Transfer.decode(Data(contentsOf: url))
        }
    }
    func handle(_ url: URL) {
        guard url.scheme == "sleepledger" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch url.host {
        case "open": break
        case "start": start()
        case "stop", "suggest-stop":
            guard var record = active else { message = "No active session; nothing changed."; return }
            record.end = Date()
            if url.host == "suggest-stop" { record.origin = .estimated }
            reviewStop = record
        case "import":
            guard let payload = components?.queryItems?.first(where: { $0.name == "payload" })?.value,
                  payload.utf8.count <= 300000 else { message = "Missing or oversized URL payload. Use a file for larger imports."; return }
            preview(Data(payload.utf8))
        case "health-written":
            guard let token = components?.queryItems?.first(where: { $0.name == "token" })?.value else { return }
            perform {
                guard let receipt = try context.fetch(FetchDescriptor<WriteReceipt>()).first(where: { $0.token == token && $0.status == "pending" }) else { throw LedgerError.invalid("Unknown or already-used Health callback.") }
                receipt.status = "reportedComplete"; try save()
                message = "The Shortcut reported completion. Check the record in Health; the app cannot independently verify Health writes."
            }
        default: message = "Unsupported SleepLedger link."
        }
    }
    func receiptKey(_ r: SleepRecord) -> String { "\(r.id)|\(Wire.string(r.start))|\(r.end.map(Wire.string) ?? "active")" }
    func receiptStatus(_ r: SleepRecord) -> String? {
        _ = receiptRevision
        return try? context.fetch(FetchDescriptor<WriteReceipt>()).first(where: { $0.key == receiptKey(r) })?.status
    }
    func healthURL(_ r: SleepRecord) throws -> URL {
        guard r.origin == .manual, let end = r.end, r.stages.isEmpty else { throw LedgerError.invalid("Only completed manual intervals without stages can be sent. Imported and estimated records are excluded.") }
        guard receiptStatus(r) == nil else { throw LedgerError.invalid("This interval already has a Health transfer receipt. Review it before retrying.") }
        let token = UUID().uuidString
        let payload = ["id": r.id.uuidString, "start": Wire.string(r.start), "end": Wire.string(end), "value": "inBed", "token": token]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self)
        var c = URLComponents(); c.scheme = "shortcuts"; c.host = "run-shortcut"
        c.queryItems = [URLQueryItem(name: "name", value: "SleepLedger Write Health"), URLQueryItem(name: "input", value: "text"), URLQueryItem(name: "text", value: json)]
        guard let url = c.url else { throw LedgerError.invalid("Could not form Shortcut URL.") }
        context.insert(WriteReceipt(key: receiptKey(r), token: token)); try save()
        return url
    }
    /// User explicitly verifies Health contains no matching interval before allowing a retry.
    func clearPendingReceipt(_ r: SleepRecord) {
        perform {
            for receipt in try context.fetch(FetchDescriptor<WriteReceipt>()) where receipt.key == receiptKey(r) && receipt.status == "pending" { context.delete(receipt) }
            try save()
        }
    }
    func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["bedtime"])
        guard settings.reminderEnabled else { return }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                settings.reminderEnabled = false; applySettings(); message = "Notifications are disabled. Enable them in iPhone Settings."; return
            }
            let content = UNMutableNotificationContent(); content.title = "Time to wind down"; content.body = "Your sleep goal is \(String(format: "%.1f", settings.goalHours)) hours."; content.sound = .default
            var dc = DateComponents(); dc.hour = settings.reminderHour; dc.minute = settings.reminderMinute
            try await center.add(UNNotificationRequest(identifier: "bedtime", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
        } catch { message = error.localizedDescription }
    }
}
