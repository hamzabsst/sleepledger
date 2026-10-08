import Foundation
import SwiftData

@Model final class SessionEntity {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(_ record: SleepRecord) throws { id = record.id; payload = try Wire.encoder().encode(record) }
    func record() throws -> SleepRecord { try Wire.decoder().decode(SleepRecord.self, from: payload) }
}
@Model final class StepsEntity {
    @Attribute(.unique) var key: String
    var payload: Data
    init(_ day: StepDay) throws { key = day.id; payload = try Wire.encoder().encode(day) }
    func value() throws -> StepDay { try Wire.decoder().decode(StepDay.self, from: payload) }
}
@Model final class WriteReceipt {
    @Attribute(.unique) var key: String
    var token: String
    var status: String
    init(key: String, token: String) { self.key = key; self.token = token; status = "pending" }
}
