import Foundation
import WidgetKit

/// Dormant unless SleepLedgerAppGroup is configured and the group container is provisioned.
/// Shares only the most recent completed night, never the SwiftData database.
enum WidgetPublisher {
    static func publish(_ sessions: [SleepRecord]) {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SleepLedgerAppGroup") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return }
        let latest = sessions.filter { $0.end != nil && !$0.isNap }.max { $0.end! < $1.end! }
        let snapshot: [String: String] = [
            "duration": latest.map { ($0.duration / 3600).sleepDuration } ?? "No nights yet",
            "wake": latest.map { Wire.string($0.end!) } ?? "",
            "origin": latest?.origin.rawValue ?? "",
            "updated": Wire.string(Date())
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: snapshot)
            try data.write(to: container.appendingPathComponent("last-night.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            WidgetCenter.shared.reloadTimelines(ofKind: "SleepLedgerLastNight")
        } catch { /* Optional display cache; the local journal is still saved. */ }
    }
}
