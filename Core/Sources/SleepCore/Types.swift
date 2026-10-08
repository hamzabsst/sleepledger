import Foundation

public enum Origin: String, Codable, CaseIterable { case manual, estimated, imported }
public enum SleepStage: String, Codable, CaseIterable {
    case inBed, awake, asleep, core, deep, rem
    public var isSleep: Bool { self != .inBed && self != .awake }
    public var title: String {
        switch self { case .inBed: return "In Bed"; case .awake: return "Awake"; case .asleep: return "Asleep (unspecified)"; case .core: return "Core"; case .deep: return "Deep"; case .rem: return "REM" }
    }
}
public struct StageInterval: Codable, Equatable {
    public var start: Date
    public var end: Date
    public var stage: SleepStage
    public init(start: Date, end: Date, stage: SleepStage) { self.start = start; self.end = end; self.stage = stage }
}
public struct SleepRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var start: Date
    public var end: Date?
    public var origin: Origin
    public var isNap: Bool
    public var quality: Int?
    public var tags: [String]
    public var source: String
    public var externalID: String?
    public var edited: Bool
    public var stages: [StageInterval]
    public var timeZoneID: String
    public init(id: UUID = UUID(), start: Date, end: Date? = nil, origin: Origin = .manual,
                isNap: Bool = false, quality: Int? = nil, tags: [String] = [], source: String = "SleepLedger",
                externalID: String? = nil, edited: Bool = false, stages: [StageInterval] = [], timeZoneID: String = TimeZone.current.identifier) {
        self.id = id; self.start = start; self.end = end; self.origin = origin; self.isNap = isNap
        self.quality = quality; self.tags = tags; self.source = source; self.externalID = externalID
        self.edited = edited; self.stages = stages; self.timeZoneID = timeZoneID
    }
    public var duration: TimeInterval {
        guard let end else { return 0 }
        let detailed = stages.filter { [.core, .deep, .rem].contains($0.stage) }
        let sleep = detailed.isEmpty ? stages.filter { $0.stage == .asleep } : detailed
        return sleep.isEmpty ? max(0, end.timeIntervalSince(start)) : Analysis.unionDuration(sleep.map { DateInterval(start: $0.start, end: $0.end) })
    }
    public func validate(now: Date = Date()) throws {
        guard start <= now, let _ = TimeZone(identifier: timeZoneID), source.count <= 200,
              tags.count <= 20, tags.allSatisfy({ $0.count <= 100 }),
              quality == nil || (1...5).contains(quality!) else { throw LedgerError.invalid("Invalid date, timezone, quality, or tags.") }
        if let end {
            guard end > start, end <= now, end.timeIntervalSince(start) <= 48 * 3600 else {
                throw LedgerError.invalid("Wake time must follow bedtime, be in the past, and be within 48 hours.")
            }
        } else if !stages.isEmpty { throw LedgerError.invalid("Active sessions cannot have stages.") }
        guard stages.count <= 3000 else { throw LedgerError.invalid("Too many stage intervals.") }
        for s in stages {
            guard let end, s.end > s.start, s.start >= start, s.end <= end else { throw LedgerError.invalid("Stage is outside the session.") }
        }
        // Different stage classifications may not overlap. In-bed/asleep summaries may overlap detailed stages.
        let detailed = stages.filter { [.awake, .core, .deep, .rem].contains($0.stage) }.sorted { $0.start < $1.start }
        for pair in zip(detailed, detailed.dropFirst()) where pair.0.end > pair.1.start {
            throw LedgerError.invalid("Overlapping detailed stages. Import one Health source at a time.")
        }
    }
}
public struct StepDay: Codable, Identifiable, Equatable {
    public var day: Date
    public var count: Int
    public var source: String
    public var id: String { "\(Int(day.timeIntervalSince1970))|\(source)" }
    public init(day: Date, count: Int, source: String) { self.day = day; self.count = count; self.source = source }
}
public struct LedgerSettings: Codable, Equatable {
    public var goalHours: Double = 8
    public var reminderEnabled: Bool = false
    public var reminderHour: Int = 22
    public var reminderMinute: Int = 30
    public var appearance: String = "system"
    public init() {}
    public func validate() throws {
        guard (4...12).contains(goalHours), (0...23).contains(reminderHour), (0...59).contains(reminderMinute), ["system", "light", "dark"].contains(appearance) else { throw LedgerError.invalid("Invalid settings.") }
    }
}
public struct TransferEnvelope: Codable {
    public var version: Int = 1
    public var sessions: [SleepRecord] = []
    public var steps: [StepDay] = []
    public var settings: LedgerSettings? = nil
    public init(sessions: [SleepRecord] = [], steps: [StepDay] = [], settings: LedgerSettings? = nil) {
        self.sessions = sessions; self.steps = steps; self.settings = settings
    }
}
public enum LedgerError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil }
}
public enum Wire {
    public static func date(_ text: String) throws -> Date {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: text) else { throw LedgerError.invalid("Use ISO 8601 dates with timezone: \(text)") }
        return d
    }
    public static func string(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, enc in var c = enc.singleValueContainer(); try c.encode(string(date)) }
        return e
    }
    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in let c = try dec.singleValueContainer(); return try date(c.decode(String.self)) }
        return d
    }
}
