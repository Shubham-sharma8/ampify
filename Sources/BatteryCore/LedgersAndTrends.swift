import Foundation
import EventKit

// MARK: - Recent 3-Hour History Strip

public struct HistoryPoint: Codable, Identifiable, Equatable, Sendable {
    public var id: Date { timestamp }
    public var timestamp: Date
    public var percentage: Int
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var watts: Double
    public var temperatureC: Double

    public init(
        timestamp: Date = Date(),
        percentage: Int,
        isPluggedIn: Bool,
        isCharging: Bool,
        watts: Double,
        temperatureC: Double
    ) {
        self.timestamp = timestamp
        self.percentage = percentage
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.watts = watts
        self.temperatureC = temperatureC
    }
}

// MARK: - High Charge Ledger (Habits Above 80%)

public struct DailyHighChargeBucket: Codable, Identifiable, Equatable, Sendable {
    public var id: String { dateKey }
    public var dateKey: String // YYYY-MM-DD
    public var date: Date
    public var pluggedMinutesAbove80: Int
    public var unpluggedMinutesAbove80: Int
    public var totalPluggedMinutes: Int
    public var peakTemperatureC: Double

    public var totalMinutesAbove80: Int {
        pluggedMinutesAbove80 + unpluggedMinutesAbove80
    }

    public var hoursAbove80: Double {
        Double(totalMinutesAbove80) / 60.0
    }

    public init(
        dateKey: String,
        date: Date,
        pluggedMinutesAbove80: Int = 0,
        unpluggedMinutesAbove80: Int = 0,
        totalPluggedMinutes: Int = 0,
        peakTemperatureC: Double = 29.0
    ) {
        self.dateKey = dateKey
        self.date = date
        self.pluggedMinutesAbove80 = pluggedMinutesAbove80
        self.unpluggedMinutesAbove80 = unpluggedMinutesAbove80
        self.totalPluggedMinutes = totalPluggedMinutes
        self.peakTemperatureC = peakTemperatureC
    }
}

public struct WeekSummary: Equatable, Sendable {
    public enum HabitGrade: String, Sendable {
        case gentle = "Gentle on battery"
        case moderate = "Moderate high-charge time"
        case heavy = "Heavy time above 80%"
    }

    public var days: [DailyHighChargeBucket]
    public var totalHoursAbove80: Double
    public var pluggedHoursAbove80: Double
    public var averageDailyHoursAbove80: Double
    public var grade: HabitGrade
    public var plainSummary: String

    public static func compute(from buckets: [DailyHighChargeBucket]) -> WeekSummary {
        let recent = Array(buckets.suffix(7))
        let totalMins = recent.reduce(0) { $0 + $1.totalMinutesAbove80 }
        let pluggedMins = recent.reduce(0) { $0 + $1.pluggedMinutesAbove80 }
        let totalHours = Double(totalMins) / 60.0
        let pluggedHours = Double(pluggedMins) / 60.0
        let avgDaily = recent.isEmpty ? 0.0 : totalHours / Double(recent.count)

        let grade: HabitGrade
        let summary: String
        if totalHours < 6.0 {
            grade = .gentle
            summary = String(format: "%.1f hrs above 80%% this week — your battery spent very little time held at a high state of charge.", totalHours)
        } else if totalHours < 21.0 {
            grade = .moderate
            summary = String(format: "%.1f hrs above 80%% this week (%.1f hrs while plugged in). Keeping the 80%% limit active on desk days will reduce wear.", totalHours, pluggedHours)
        } else {
            grade = .heavy
            summary = String(format: "%.1f hrs above 80%% this week. Staying plugged in near 100%% accelerates chemical aging — enable the 80%% limit.", totalHours)
        }

        return WeekSummary(
            days: recent,
            totalHoursAbove80: totalHours,
            pluggedHoursAbove80: pluggedHours,
            averageDailyHoursAbove80: avgDaily,
            grade: grade,
            plainSummary: summary
        )
    }
}

// MARK: - Long-Term Health Trend & Projection

public struct HealthSample: Codable, Identifiable, Equatable, Sendable {
    public var id: String { dateKey }
    public var dateKey: String
    public var date: Date
    public var healthPercent: Int
    public var nominalCapacitymAh: Int
    public var designCapacitymAh: Int
    public var cycleCount: Int

    public init(
        dateKey: String,
        date: Date,
        healthPercent: Int,
        nominalCapacitymAh: Int,
        designCapacitymAh: Int,
        cycleCount: Int
    ) {
        self.dateKey = dateKey
        self.date = date
        self.healthPercent = healthPercent
        self.nominalCapacitymAh = nominalCapacitymAh
        self.designCapacitymAh = designCapacitymAh
        self.cycleCount = cycleCount
    }
}

public enum HealthTimeRange: String, CaseIterable, Sendable {
    case ninetyDays = "90 Days"
    case oneYear = "1 Year"
    case allTime = "All Time"
}

public struct HealthProjection: Equatable, Sendable {
    public var currentHealthPercent: Int
    public var dropPerYearPercent: Double
    public var estimatedMonthsTo80: Int?
    public var estimatedDateAt80: Date?
    public var headline: String
    public var detail: String

    public static func analyze(samples: [HealthSample], currentReading: BatteryReading) -> HealthProjection {
        let sorted = samples.sorted { $0.date < $1.date }
        let currentHealth = currentReading.healthPercent

        guard sorted.count >= 2,
              let first = sorted.first,
              let last = sorted.last else {
            return HealthProjection(
                currentHealthPercent: currentHealth,
                dropPerYearPercent: 2.5,
                estimatedMonthsTo80: currentHealth > 80 ? Int(Double(currentHealth - 80) / (2.5 / 12.0)) : 0,
                estimatedDateAt80: Calendar.current.date(byAdding: .month, value: max(1, (currentHealth - 80) * 4), to: Date()),
                headline: "\(currentHealth)% of original capacity (\(currentReading.nominalCapacitymAh) of \(currentReading.designCapacitymAh) mAh)",
                detail: "Apple rates this Mac battery for \(currentReading.designCycleCount) cycles before crossing the 80% service threshold. You are at \(currentReading.cycleCount) cycles."
            )
        }

        let spanDays = max(30.0, last.date.timeIntervalSince(first.date) / 86400.0)
        let rawDrop = Double(first.healthPercent - last.healthPercent)
        let annualizedDrop = max(1.2, min(12.0, (rawDrop / spanDays) * 365.25))

        let remainingAbove80 = Double(max(0, currentHealth - 80))
        let yearsLeft = remainingAbove80 / annualizedDrop
        let monthsLeft = Int((yearsLeft * 12.0).rounded())
        let targetDate = Calendar.current.date(byAdding: .month, value: monthsLeft, to: Date())

        let detailText: String
        if currentHealth <= 80 {
            detailText = "Battery capacity has reached Apple's 80% service threshold (\(currentReading.cycleCount) cycles)."
        } else if monthsLeft > 36 {
            detailText = String(format: "Losing about %.1f%% per year. At this pace, your battery stays above the 80%% service threshold for 3+ years.", annualizedDrop)
        } else {
            detailText = String(format: "Losing about %.1f%% per year. Projected to reach the 80%% service line in roughly %d months.", annualizedDrop, max(1, monthsLeft))
        }

        return HealthProjection(
            currentHealthPercent: currentHealth,
            dropPerYearPercent: annualizedDrop,
            estimatedMonthsTo80: monthsLeft,
            estimatedDateAt80: targetDate,
            headline: "\(currentHealth)% capacity · \(currentReading.cycleCount) of \(currentReading.designCycleCount) cycles",
            detail: detailText
        )
    }
}

// MARK: - Apple Out-of-Warranty Battery Service Lookup (service-prices.json)

public struct BatteryServiceEstimate: Equatable, Sendable {
    public var modelIdentifier: String
    public var regionCode: String
    public var currency: String
    public var amount: Int
    public var formattedPrice: String
    public var asOfDate: String

    public init(
        modelIdentifier: String,
        regionCode: String,
        currency: String,
        amount: Int,
        formattedPrice: String,
        asOfDate: String
    ) {
        self.modelIdentifier = modelIdentifier
        self.regionCode = regionCode
        self.currency = currency
        self.amount = amount
        self.formattedPrice = formattedPrice
        self.asOfDate = asOfDate
    }
}

public enum BatteryServiceCatalog {
    private struct PriceFile: Decodable {
        struct RegionEntry: Decodable {
            struct Tier: Decodable {
                let amount: Int
                let models: [String]
            }
            let asOf: String
            let currency: String
            let locale: String
            let tiers: [Tier]
        }
        let regions: [String: RegionEntry]
    }

    public static func estimate(
        forModel modelIdentifier: String = IOKitBatterySource.currentHardwareModelIdentifier(),
        regionCode: String? = Locale.current.region?.identifier
    ) -> BatteryServiceEstimate {
        let chosenRegion = ["US", "CA", "GB", "DE", "FR", "JP"].contains(regionCode ?? "US") ? (regionCode ?? "US") : "US"

        if let url = AmpifyResourceBundle.url(forResource: "service-prices", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(PriceFile.self, from: data),
           let entry = decoded.regions[chosenRegion] ?? decoded.regions["US"] {
            let matchedTier = entry.tiers.first(where: { $0.models.contains(modelIdentifier) })
                ?? entry.tiers.first(where: { tier in
                    modelIdentifier.hasPrefix("MacBookAir") && tier.models.contains("MacBookAir10,1")
                })
                ?? entry.tiers.first

            let amount = matchedTier?.amount ?? 159
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = entry.currency
            formatter.maximumFractionDigits = 0
            formatter.locale = Locale(identifier: entry.locale)
            let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(entry.currency) \(amount)"

            return BatteryServiceEstimate(
                modelIdentifier: modelIdentifier,
                regionCode: chosenRegion,
                currency: entry.currency,
                amount: amount,
                formattedPrice: formatted,
                asOfDate: entry.asOf
            )
        }

        return BatteryServiceEstimate(
            modelIdentifier: modelIdentifier,
            regionCode: "US",
            currency: "USD",
            amount: 159,
            formattedPrice: "$159",
            asOfDate: "2026-11-11"
        )
    }
}

// MARK: - Departure Learning & Calendar Trip Trigger

public struct DeparturePrediction: Codable, Equatable, Sendable {
    public var weekday: Int // 1 = Sun ... 7 = Sat
    public var typicalMinuteOfDay: Int // e.g. 8:30 AM = 510
    public var confidence: Double // 0.0 ... 1.0
    public var sampleCount: Int

    public init(weekday: Int, typicalMinuteOfDay: Int, confidence: Double, sampleCount: Int) {
        self.weekday = weekday
        self.typicalMinuteOfDay = typicalMinuteOfDay
        self.confidence = confidence
        self.sampleCount = sampleCount
    }

    public var formattedTime: String {
        let hour24 = (typicalMinuteOfDay / 60) % 24
        let minute = typicalMinuteOfDay % 60
        var comps = DateComponents()
        comps.hour = hour24
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var topUpStartFormattedTime: String {
        let startMins = max(0, typicalMinuteOfDay - 75)
        var comps = DateComponents()
        comps.hour = (startMins / 60) % 24
        comps.minute = startMins % 60
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public struct CalendarTripMatch: Identifiable, Equatable, Sendable {
    public var id: String { "\(title)-\(startDate.timeIntervalSince1970)" }
    public var title: String
    public var startDate: Date
    public var isAllDay: Bool
    public var matchedKeyword: String
    public var topUpScheduledAt: Date

    public init(
        title: String,
        startDate: Date,
        isAllDay: Bool,
        matchedKeyword: String,
        topUpScheduledAt: Date
    ) {
        self.title = title
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.matchedKeyword = matchedKeyword
        self.topUpScheduledAt = topUpScheduledAt
    }
}

public final class EventKitCalendarScanner: @unchecked Sendable {
    public static let defaultKeywords: [String] = [
        "flight", "fly", "airport", "train", "eurostar", "amtrak", "trip",
        "travel", "conference", "offsite", "vacation", "hotel", "depart"
    ]

    private let store = EKEventStore()

    public init() {}

    public var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    public func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    public func upcomingTrips(keywords: [String] = EventKitCalendarScanner.defaultKeywords, includeAllDayEvents: Bool = false) -> [CalendarTripMatch] {
        let status = authorizationStatus
        guard status == .fullAccess else {
            return []
        }

        let now = Date()
        let horizon = now.addingTimeInterval(48 * 3600)
        let predicate = store.predicateForEvents(withStart: now, end: horizon, calendars: nil)
        let events = store.events(matching: predicate)

        var matches: [CalendarTripMatch] = []
        let loweredKeywords = keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }

        for event in events {
            let title = event.title ?? ""
            let notes = event.notes ?? ""
            let location = event.location ?? ""
            let haystack = "\(title) \(location) \(notes)".lowercased()

            var matched: String? = loweredKeywords.first(where: { haystack.contains($0) })
            if matched == nil && includeAllDayEvents && event.isAllDay {
                matched = "All-day event"
            }

            if let matchedKeyword = matched {
                let cal = Calendar.current
                let eventDay = cal.startOfDay(for: event.startDate)
                let nightBefore = cal.date(byAdding: .day, value: -1, to: eventDay) ?? now
                let scheduled = cal.date(bySettingHour: 20, minute: 0, second: 0, of: nightBefore) ?? now
                matches.append(
                    CalendarTripMatch(
                        title: title.isEmpty ? "Upcoming Trip" : title,
                        startDate: event.startDate,
                        isAllDay: event.isAllDay,
                        matchedKeyword: matchedKeyword,
                        topUpScheduledAt: max(now, scheduled)
                    )
                )
            }
        }
        return matches.sorted { $0.startDate < $1.startDate }
    }
}
