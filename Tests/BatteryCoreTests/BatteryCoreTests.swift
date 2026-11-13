import XCTest
@testable import BatteryCore

final class BatteryCoreTests: XCTestCase {
    func testIOKitBatteryReadingProducesValidValues() {
        let reading = IOKitBatterySource.shared.readCurrent()
        XCTAssertTrue((0...100).contains(reading.percentage))
        XCTAssertTrue((10...100).contains(reading.healthPercent))
        XCTAssertGreaterThan(reading.designCapacitymAh, 0)
    }

    func testStatusExplanationHoldingAtLimit() {
        let reading = BatteryReading(
            percentage: 80,
            isPluggedIn: true,
            isCharging: false,
            activeChargeLimit: 80,
            storedChargeLimit: 80
        )
        let watchdog = LimitWatchdog.evaluate(reading: reading, userWantsLimit: true, fullChargeSession: nil)
        XCTAssertEqual(watchdog, .holding(limit: 80))

        let explanation = StatusExplanation.explain(
            reading: reading,
            limitStatus: watchdog,
            fullChargeSession: nil,
            recalibrating: false
        )
        XCTAssertEqual(explanation.tone, .good)
        XCTAssertTrue(explanation.headline.contains("80%"))
    }

    func testServicePriceCatalogLookupAcrossRegions() {
        let us = BatteryServiceCatalog.estimate(forModel: "Mac15,12", regionCode: "US")
        XCTAssertEqual(us.currency, "USD")
        XCTAssertEqual(us.amount, 159)

        let de = BatteryServiceCatalog.estimate(forModel: "Mac15,12", regionCode: "DE")
        XCTAssertEqual(de.currency, "EUR")
        XCTAssertEqual(de.amount, 185)
    }

    func testWeekSummaryCalculation() {
        let buckets = [
            DailyHighChargeBucket(dateKey: "2026-11-10", date: Date(), pluggedMinutesAbove80: 60, unpluggedMinutesAbove80: 30),
            DailyHighChargeBucket(dateKey: "2026-11-11", date: Date(), pluggedMinutesAbove80: 30, unpluggedMinutesAbove80: 0)
        ]
        let summary = WeekSummary.compute(from: buckets)
        XCTAssertEqual(summary.totalHoursAbove80, 2.0, accuracy: 0.01)
        XCTAssertEqual(summary.grade, .gentle)
    }
}
