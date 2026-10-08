import Foundation

public enum CSV {
    public static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = ""
        var quoted = false, closed = false
        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i+1] == "\"" { cell.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { cell.append(c) }
            } else if c == "," { row.append(cell); cell = ""; closed = false }
            else if c == "\n" { row.append(cell); rows.append(row); row = []; cell = ""; closed = false }
            else if c == "\"" && cell.isEmpty && !closed { quoted = true }
            else if closed || c == "\"" { throw LedgerError.invalid("Malformed CSV quoting.") }
            else { cell.append(c) }
            i += 1
        }
        guard !quoted else { throw LedgerError.invalid("Unclosed CSV quote.") }
        if !cell.isEmpty || !row.isEmpty || closed { row.append(cell); rows.append(row) }
        return rows.filter { !$0.allSatisfy(\.isEmpty) }
    }
    public static func row(_ cells: [String]) -> String { cells.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }
}
public enum Transfer {
    public static let maxBytes = 8 * 1024 * 1024
    public static let header = ["id", "start", "end", "origin", "isNap", "quality", "tags_json", "source", "externalID", "edited", "timeZoneID", "stages_json"]
    public static func decode(_ data: Data, now: Date = Date()) throws -> TransferEnvelope {
        guard data.count <= maxBytes, let text = String(data: data, encoding: .utf8) else { throw LedgerError.invalid("Use UTF-8 CSV/JSON smaller than 8 MB.") }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let envelope: TransferEnvelope
        if trimmed.hasPrefix("{") { envelope = try Wire.decoder().decode(TransferEnvelope.self, from: data) }
        else { envelope = try decodeCSV(trimmed) }
        guard envelope.version == 1, envelope.sessions.count <= 10000, envelope.steps.count <= 10000,
              envelope.sessions.filter({ $0.end == nil }).count <= 1 else { throw LedgerError.invalid("Unsupported version or too many records/active sessions.") }
        for record in envelope.sessions { try record.validate(now: now) }
        for day in envelope.steps {
            guard day.day <= now, (0...200000).contains(day.count), day.source.count <= 200 else { throw LedgerError.invalid("Invalid steps.") }
        }
        try envelope.settings?.validate()
        return envelope
    }
    public static func exportCSV(_ records: [SleepRecord]) throws -> String {
        try ([CSV.row(header)] + records.map { r in
            CSV.row([r.id.uuidString, Wire.string(r.start), r.end.map(Wire.string) ?? "", r.origin.rawValue,
                     String(r.isNap), r.quality.map(String.init) ?? "", String(decoding: try Wire.encoder().encode(r.tags), as: UTF8.self),
                     r.source, r.externalID ?? "", String(r.edited), r.timeZoneID,
                     String(decoding: try Wire.encoder().encode(r.stages), as: UTF8.self)])
        }).joined(separator: "\n")
    }
    static func decodeCSV(_ text: String) throws -> TransferEnvelope {
        var rows = try CSV.parse(text)
        guard let keys = rows.first, Set(keys).count == keys.count else { throw LedgerError.invalid("Missing or duplicate CSV columns.") }
        rows.removeFirst()
        if keys == ["kind", "start", "end", "source", "value"] { return try healthCSV(rows) }
        guard keys == header else { throw LedgerError.invalid("CSV columns do not match. See Examples and SHORTCUTS.md.") }
        var records: [SleepRecord] = []
        for cells in rows {
            guard cells.count == header.count, let id = UUID(uuidString: cells[0]), let origin = Origin(rawValue: cells[3]),
                  let nap = Bool(cells[4]), let edited = Bool(cells[9]),
                  cells[5].isEmpty || Int(cells[5]) != nil else { throw LedgerError.invalid("Invalid session CSV row.") }
            records.append(SleepRecord(id: id, start: try Wire.date(cells[1]), end: cells[2].isEmpty ? nil : try Wire.date(cells[2]), origin: origin,
                isNap: nap, quality: Int(cells[5]), tags: try Wire.decoder().decode([String].self, from: Data(cells[6].utf8)),
                source: cells[7], externalID: cells[8].isEmpty ? nil : cells[8], edited: edited,
                stages: try Wire.decoder().decode([StageInterval].self, from: Data(cells[11].utf8)), timeZoneID: cells[10]))
        }
        return TransferEnvelope(sessions: records)
    }
    static func healthCSV(_ rows: [[String]]) throws -> TransferEnvelope {
        var stages: [StageInterval] = [], sources = Set<String>(), steps: [StepDay] = []
        var seen = Set<String>()
        for c in rows {
            guard c.count == 5 else { throw LedgerError.invalid("Health CSV needs five columns.") }
            let start = try Wire.date(c[1]), end = try Wire.date(c[2])
            guard end > start, end.timeIntervalSince(start) <= 48 * 3600 else { throw LedgerError.invalid("Health interval must have positive duration.") }
            let key = c.joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            if c[0] == "steps" {
                guard let count = Int(c[4]) else { throw LedgerError.invalid("Steps must be a whole-number daily total.") }
                steps.append(StepDay(day: start, count: count, source: c[3])); continue
            }
            guard c[0] == "sleep", let stage = SleepStage(rawValue: c[4]) else {
                throw LedgerError.invalid("Use sleep values inBed, asleep, awake, core, deep, rem. Map localized labels explicitly in the Shortcut.")
            }
            stages.append(StageInterval(start: start, end: end, stage: stage)); sources.insert(c[3])
        }
        guard sources.count <= 1 else { throw LedgerError.invalid("Select ONE sleep source in Shortcuts. Mixing sources can double-count or contradict stages.") }
        // Group contiguous intervals, allowing up to 90 minutes between samples. User can edit/split afterward.
        var groups: [[StageInterval]] = []
        for s in stages.sorted(by: { $0.start < $1.start }) {
            if let last = groups.last, s.start.timeIntervalSince(last.map(\.end).max()!) <= 90 * 60 { groups[groups.count-1].append(s) }
            else { groups.append([s]) }
        }
        let source = sources.first ?? "Health via Shortcuts"
        let sessions = groups.compactMap { group -> SleepRecord? in
            let asleep = group.filter { $0.stage.isSleep }
            let base = asleep.isEmpty ? group.filter { $0.stage == .inBed } : asleep
            guard let start = base.map(\.start).min(), let end = base.map(\.end).max() else { return nil }
            let clipped = group.compactMap { s -> StageInterval? in
                let a = max(start, s.start), b = min(end, s.end)
                return a < b ? StageInterval(start: a, end: b, stage: s.stage) : nil
            }
            return SleepRecord(start: start, end: end, origin: .imported, source: source,
                externalID: "health|\(source)|\(Wire.string(start))|\(Wire.string(end))", stages: clipped)
        }
        return TransferEnvelope(sessions: sessions, steps: steps)
    }
    public enum Match: Equatable { case duplicate, overlap, new }
    public static func match(_ incoming: SleepRecord, existing: [SleepRecord]) -> Match {
        if existing.contains(where: { $0.id == incoming.id || (incoming.externalID != nil && $0.externalID == incoming.externalID && $0.source == incoming.source) || ($0.start == incoming.start && $0.end == incoming.end) }) { return .duplicate }
        if existing.contains(where: { max($0.start, incoming.start) < min($0.end ?? .distantFuture, incoming.end ?? .distantFuture) }) { return .overlap }
        return .new
    }
}
