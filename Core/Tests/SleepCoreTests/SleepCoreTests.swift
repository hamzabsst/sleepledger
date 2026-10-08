import XCTest
@testable import SleepCore

final class SleepCoreTests: XCTestCase {
    func d(_ text: String) -> Date { try! Wire.date(text) }
    var now: Date { d("2026-10-08T15:00:00Z") }
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func record(_ a: String, _ b: String, nap: Bool = false) -> SleepRecord { SleepRecord(start: d(a), end: d(b), isNap: nap, timeZoneID: "UTC") }

    func testCircularMidnightMeanAndVariation() {
        let mean = Analysis.circularMean([1430, 10])!
        XCTAssertLessThan(Analysis.clockDistance(mean, 0), 0.01)
        let records = [record("2026-10-05T23:50:00Z", "2026-10-06T08:00:00Z"), record("2026-10-07T00:10:00Z", "2026-10-07T08:00:00Z")]
        XCTAssertEqual(Analysis.variation(records, calendar: calendar)!, 10, accuracy: 0.01)
    }
    func testUnknownDaysAreExcludedAndNapsCountOnce() {
        let records = [record("2026-10-07T23:00:00Z", "2026-10-08T06:00:00Z"), record("2026-10-08T12:00:00Z", "2026-10-08T13:00:00Z", nap: true)]
        let days = Analysis.window(records, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(days.count, 1); XCTAssertEqual(days[0].hours, 8)
        XCTAssertEqual(Analysis.debt(days, goal: 8), 0)
        XCTAssertEqual(Analysis.average(days.map(\.hours)), 8)
    }
    func testOverlapAndIDProtection() {
        let manual = record("2026-10-07T23:00:00Z", "2026-10-08T07:00:00Z")
        var imported = manual; imported.id = UUID(); imported.origin = .imported
        XCTAssertEqual(Transfer.match(imported, existing: [manual]), .duplicate)
        imported.end = d("2026-10-08T08:00:00Z")
        XCTAssertEqual(Transfer.match(imported, existing: [manual]), .overlap)
        imported.id = manual.id
        XCTAssertEqual(Transfer.match(imported, existing: [manual]), .duplicate)
    }
    func testJSONAndCSVPreserveStagesProvenanceAndQuotedTags() throws {
        var r = record("2026-10-07T23:00:00Z", "2026-10-08T07:00:00Z")
        r.origin = .imported; r.quality = 4; r.tags = ["stress, work", "a \"quote\"\nand newline"]
        r.stages = [StageInterval(start: r.start, end: r.end!, stage: .core)]
        let csv = try Transfer.exportCSV([r])
        XCTAssertEqual(try Transfer.decode(Data(csv.utf8), now: now).sessions, [r])
        let json = try Wire.encoder().encode(TransferEnvelope(sessions: [r]))
        XCTAssertEqual(try Transfer.decode(json, now: now).sessions, [r])
        XCTAssertThrowsError(try CSV.parse("\"unclosed"))
        XCTAssertThrowsError(try CSV.parse("\"x\"junk"))
    }
    func testRawHealthGroupingUnionAndAwakeExclusion() throws {
        let csv = """
        kind,start,end,source,value
        sleep,2026-10-07T23:00:00Z,2026-10-08T07:00:00Z,Watch,inBed
        sleep,2026-10-07T23:00:00Z,2026-10-08T07:00:00Z,Watch,asleep
        sleep,2026-10-07T23:00:00Z,2026-10-08T03:00:00Z,Watch,core
        sleep,2026-10-08T03:00:00Z,2026-10-08T03:30:00Z,Watch,awake
        sleep,2026-10-08T03:30:00Z,2026-10-08T07:00:00Z,Watch,rem
        sleep,2026-10-08T03:30:00Z,2026-10-08T07:00:00Z,Watch,rem
        """
        let records = try Transfer.decode(Data(csv.utf8), now: now).sessions
        XCTAssertEqual(records.count, 1); XCTAssertEqual(records[0].origin, .imported)
        XCTAssertEqual(records[0].duration, 7.5 * 3600)
        XCTAssertEqual(records[0].stages.count, 5)
    }
    func testRejectMixedSourcesAndOverlappingStages() throws {
        let csv = """
        kind,start,end,source,value
        sleep,2026-10-07T23:00:00Z,2026-10-08T07:00:00Z,Watch,asleep
        sleep,2026-10-07T23:00:00Z,2026-10-08T07:00:00Z,Phone,asleep
        """
        XCTAssertThrowsError(try Transfer.decode(Data(csv.utf8), now: now))
        var r = record("2026-10-07T23:00:00Z", "2026-10-08T07:00:00Z")
        r.stages = [StageInterval(start: r.start, end: r.end!, stage: .core), StageInterval(start: r.start, end: r.end!, stage: .deep)]
        XCTAssertThrowsError(try r.validate(now: now))
    }
    func testScheduleRequiresThreeExcludesNapsAndEstimates() {
        var records = (5...7).map { day in record("2026-10-0\(day)T00:00:00Z", "2026-10-0\(day)T08:00:00Z") }
        XCTAssertEqual(Analysis.schedule(records, weekend: false, now: now, calendar: calendar)?.count, 3)
        XCTAssertNil(Analysis.schedule(records, weekend: true, now: now, calendar: calendar))
        records[0].origin = .estimated
        XCTAssertNil(Analysis.schedule(records, weekend: false, now: now, calendar: calendar))
        records[0].origin = .manual; records[0].isNap = true
        XCTAssertNil(Analysis.schedule(records, weekend: false, now: now, calendar: calendar))
    }
    func testSuggestedWakeAndNoFutureSuggestion() {
        let records = (5...7).map { day in record("2026-10-0\(day)T00:00:00Z", "2026-10-0\(day)T08:00:00Z") }
        let start = d("2026-10-08T00:00:00Z")
        XCTAssertEqual(Analysis.suggestedWake(start: start, records: records, now: now, calendar: calendar), d("2026-10-08T08:00:00Z"))
        XCTAssertNil(Analysis.suggestedWake(start: start, records: records, now: d("2026-10-08T07:00:00Z"), calendar: calendar))
    }
    func testDSTUsesElapsedSeconds() {
        let r = record("2026-10-24T23:00:00+01:00", "2026-10-25T08:00:00Z")
        XCTAssertEqual(r.duration, 10 * 3600)
    }
    func testValidationAndStageBounds() {
        var r = record("2026-10-08T07:00:00Z", "2026-10-08T06:00:00Z")
        XCTAssertThrowsError(try r.validate(now: now))
        r.end = d("2026-10-09T08:00:00Z")
        XCTAssertThrowsError(try r.validate(now: now))
        r.end = d("2026-10-08T08:00:00Z"); r.quality = 6
        XCTAssertThrowsError(try r.validate(now: now))
    }
}
