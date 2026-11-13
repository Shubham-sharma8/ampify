import Foundation

public enum DetailLevel: String, CaseIterable, Codable, Sendable {
    case simple
    case technical

    public var label: String {
        switch self {
        case .simple: return "Simple"
        case .technical: return "Technical"
        }
    }
}

public enum MenuBarStyle: String, CaseIterable, Codable, Sendable {
    case percent
    case timeLeft
    case watts
    case icon

    public var label: String {
        switch self {
        case .percent: return "Percentage (78%)"
        case .timeLeft: return "Time Left (4h 20m)"
        case .watts: return "Power (12 W)"
        case .icon: return "Icon Only"
        }
    }
}

public enum ThermalBand: String, Codable, Sendable {
    case cool
    case normal
    case warm
    case hot

    public static func from(celsius: Double) -> ThermalBand {
        if celsius >= 40.0 { return .hot }
        if celsius >= 35.0 { return .warm }
        if celsius < 22.0 { return .cool }
        return .normal
    }

    public var label: String {
        switch self {
        case .cool: return "Cool"
        case .normal: return "Comfortable"
        case .warm: return "Warm"
        case .hot: return "Hot"
        }
    }
}

public struct BatteryReading: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var percentage: Int
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var isFullyCharged: Bool
    public var activeChargeLimit: Int?
    public var storedChargeLimit: Int
    public var isLimitSupported: Bool
    public var limitUnavailableReason: String?
    public var healthPercent: Int
    public var nominalCapacitymAh: Int
    public var rawMaxCapacitymAh: Int
    public var designCapacitymAh: Int
    public var currentCapacitymAh: Int
    public var cycleCount: Int
    public var designCycleCount: Int
    public var temperatureCelsius: Double
    public var voltageVolts: Double
    public var amperageAmps: Double
    public var batteryWatts: Double
    public var systemPowerInWatts: Double?
    public var systemLoadWatts: Double?
    public var adapterWatts: Int?
    public var timeRemainingMinutes: Int?
    public var notChargingReasonCode: Int?
    public var slowChargingReasonCode: Int?
    public var thermallyLimitedSeconds: Int?
    public var obcEngaged: Bool
    public var maxChargeLimited: Bool

    public init(
        timestamp: Date = Date(),
        percentage: Int = 80,
        isPluggedIn: Bool = true,
        isCharging: Bool = false,
        isFullyCharged: Bool = false,
        activeChargeLimit: Int? = 80,
        storedChargeLimit: Int = 80,
        isLimitSupported: Bool = true,
        limitUnavailableReason: String? = nil,
        healthPercent: Int = 96,
        nominalCapacitymAh: Int = 4320,
        rawMaxCapacitymAh: Int = 4310,
        designCapacitymAh: Int = 4500,
        currentCapacitymAh: Int = 3456,
        cycleCount: Int = 84,
        designCycleCount: Int = 1000,
        temperatureCelsius: Double = 29.4,
        voltageVolts: Double = 12.15,
        amperageAmps: Double = 0.0,
        batteryWatts: Double = 0.0,
        systemPowerInWatts: Double? = 14.2,
        systemLoadWatts: Double? = 14.0,
        adapterWatts: Int? = 67,
        timeRemainingMinutes: Int? = nil,
        notChargingReasonCode: Int? = nil,
        slowChargingReasonCode: Int? = nil,
        thermallyLimitedSeconds: Int? = nil,
        obcEngaged: Bool = false,
        maxChargeLimited: Bool = true
    ) {
        self.timestamp = timestamp
        self.percentage = percentage
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.isFullyCharged = isFullyCharged
        self.activeChargeLimit = activeChargeLimit
        self.storedChargeLimit = storedChargeLimit
        self.isLimitSupported = isLimitSupported
        self.limitUnavailableReason = limitUnavailableReason
        self.healthPercent = healthPercent
        self.nominalCapacitymAh = nominalCapacitymAh
        self.rawMaxCapacitymAh = rawMaxCapacitymAh
        self.designCapacitymAh = designCapacitymAh
        self.currentCapacitymAh = currentCapacitymAh
        self.cycleCount = cycleCount
        self.designCycleCount = designCycleCount
        self.temperatureCelsius = temperatureCelsius
        self.voltageVolts = voltageVolts
        self.amperageAmps = amperageAmps
        self.batteryWatts = batteryWatts
        self.systemPowerInWatts = systemPowerInWatts
        self.systemLoadWatts = systemLoadWatts
        self.adapterWatts = adapterWatts
        self.timeRemainingMinutes = timeRemainingMinutes
        self.notChargingReasonCode = notChargingReasonCode
        self.slowChargingReasonCode = slowChargingReasonCode
        self.thermallyLimitedSeconds = thermallyLimitedSeconds
        self.obcEngaged = obcEngaged
        self.maxChargeLimited = maxChargeLimited
    }

    public var thermalBand: ThermalBand {
        ThermalBand.from(celsius: temperatureCelsius)
    }

    public var isRunningOffPowerAdapter: Bool {
        isPluggedIn && !isCharging && abs(amperageAmps) < 0.08
    }

    public var formattedTimeRemaining: String? {
        guard let mins = timeRemainingMinutes, mins > 0, mins < 1440 else { return nil }
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }
}

public struct StatusExplanation: Equatable, Sendable {
    public enum Tone: String, Sendable {
        case good
        case neutral
        case caution
        case alert
    }

    public var headline: String
    public var detail: String
    public var technicalLine: String
    public var tone: Tone
    public var badgeText: String

    public init(headline: String, detail: String, technicalLine: String, tone: Tone, badgeText: String) {
        self.headline = headline
        self.detail = detail
        self.technicalLine = technicalLine
        self.tone = tone
        self.badgeText = badgeText
    }

    public static func explain(
        reading: BatteryReading,
        limitStatus: LimitWatchdog.Status,
        fullChargeSession: FullChargeSession?,
        recalibrating: Bool
    ) -> StatusExplanation {
        let techParts: [String] = [
            String(format: "%.2f V", reading.voltageVolts),
            String(format: "%+.2f A", reading.amperageAmps),
            String(format: "%.1f W", reading.batteryWatts),
            reading.adapterWatts.map { "\($0)W adapter" } ?? (reading.isPluggedIn ? "AC power" : "Battery power"),
            String(format: "%.1f °C", reading.temperatureCelsius),
            "\(reading.currentCapacitymAh)/\(reading.nominalCapacitymAh) mAh"
        ]
        let techLine = techParts.joined(separator: " · ")

        if let session = fullChargeSession {
            return StatusExplanation(
                headline: reading.percentage >= 100
                    ? "At 100% — temporary full charge complete."
                    : "Charging to 100% once (\(session.restoreSummary)).",
                detail: "Your \(reading.storedChargeLimit)% charge limit will automatically turn back on \(session.restorePhrase).",
                technicalLine: techLine,
                tone: .neutral,
                badgeText: "Charging to 100% Once"
            )
        }

        if recalibrating {
            return StatusExplanation(
                headline: "macOS is recalibrating the battery gauge.",
                detail: "Every few weeks macOS charges to 100% so the percentage stays accurate, then returns to \(reading.storedChargeLimit)%.",
                technicalLine: techLine + " · powerd batterygauging active",
                tone: .caution,
                badgeText: "Recalibrating"
            )
        }

        if case .overshootSuspected(let limit) = limitStatus {
            return StatusExplanation(
                headline: "Charged past your \(limit)% limit.",
                detail: "macOS temporarily overrode the limit. This happens during periodic battery gauge calibration, after a macOS update, or while sleeping.",
                technicalLine: techLine + " · Limit slip above \(limit)%",
                tone: .caution,
                badgeText: "Limit Paused by macOS"
            )
        }

        if reading.isPluggedIn {
            if let limit = reading.activeChargeLimit, limit < 100 {
                if !reading.isCharging && abs(reading.percentage - limit) <= 2 {
                    return StatusExplanation(
                        headline: "Holding at \(limit)% — running from the power adapter.",
                        detail: "Your battery is resting and bypassing charge cycles while your Mac runs directly off wall power.",
                        technicalLine: techLine,
                        tone: .good,
                        badgeText: "Holding at \(limit)%"
                    )
                } else if reading.isCharging && reading.percentage < limit {
                    let eta = reading.formattedTimeRemaining.map { " · about \($0) to \(limit)%" } ?? ""
                    return StatusExplanation(
                        headline: "Charging toward your \(limit)% limit\(eta).",
                        detail: "Ampify will stop charging at \(limit)% and switch your Mac to wall power.",
                        technicalLine: techLine,
                        tone: .good,
                        badgeText: "Charging to \(limit)%"
                    )
                } else if !reading.isCharging && reading.percentage > limit {
                    return StatusExplanation(
                        headline: "Above your \(limit)% limit — paused charging.",
                        detail: "Currently at \(reading.percentage)%. Charging remains paused until the battery naturally drops to \(limit)%.",
                        technicalLine: techLine,
                        tone: .neutral,
                        badgeText: "Paused Above \(limit)%"
                    )
                }
            }

            if reading.isFullyCharged || reading.percentage >= 99 {
                return StatusExplanation(
                    headline: "Fully charged at \(reading.percentage)%.",
                    detail: reading.activeChargeLimit == nil
                        ? "Turn on the 80% charge limit if you stay plugged in at a desk."
                        : "Running off your power adapter.",
                    technicalLine: techLine,
                    tone: reading.activeChargeLimit == nil ? .caution : .neutral,
                    badgeText: "Full Charge"
                )
            }

            if reading.isCharging {
                let eta = reading.formattedTimeRemaining.map { " · \($0) to full" } ?? ""
                return StatusExplanation(
                    headline: "Charging at \(String(format: "%.0f W", max(1, reading.batteryWatts)))\(eta).",
                    detail: reading.adapterWatts.map { "Connected to a \($0)W power adapter." } ?? "Connected to external power.",
                    technicalLine: techLine,
                    tone: .neutral,
                    badgeText: "Charging"
                )
            }

            return StatusExplanation(
                headline: "Plugged in — battery not charging.",
                detail: "Your Mac is drawing power from the adapter while holding battery charge steady.",
                technicalLine: techLine,
                tone: .neutral,
                badgeText: "On Adapter"
            )
        } else {
            let eta = reading.formattedTimeRemaining.map { "About \($0) remaining" } ?? "Running on battery power"
            let wattsStr = String(format: "%.1f W", abs(reading.batteryWatts))
            let tone: Tone = reading.percentage <= 20 ? .caution : .neutral
            return StatusExplanation(
                headline: "\(eta) at current use (\(wattsStr)).",
                detail: reading.percentage <= 20
                    ? "Battery is getting low. Plug in or turn on Low Power Mode to stretch runtime."
                    : "Unplugged and discharging normally.",
                technicalLine: techLine,
                tone: tone,
                badgeText: "On Battery"
            )
        }
    }
}

public struct FullChargeSession: Codable, Equatable, Sendable {
    public enum RestoreTrigger: String, CaseIterable, Codable, Sendable {
        case onUnplug
        case whenFull
        case afterHours

        public var label: String {
            switch self {
            case .onUnplug: return "When unplugged"
            case .whenFull: return "As soon as it reaches 100%"
            case .afterHours: return "After time limit"
            }
        }
    }

    public var startedAt: Date
    public var deadline: Date
    public var restoreOnUnplug: Bool
    public var restoreWhenFull: Bool
    public var reason: String?

    public init(
        startedAt: Date = Date(),
        deadline: Date = Date().addingTimeInterval(8 * 3600),
        restoreOnUnplug: Bool = true,
        restoreWhenFull: Bool = false,
        reason: String? = nil
    ) {
        self.startedAt = startedAt
        self.deadline = deadline
        self.restoreOnUnplug = restoreOnUnplug
        self.restoreWhenFull = restoreWhenFull
        self.reason = reason
    }

    public var restoreSummary: String {
        if let reason, !reason.isEmpty {
            return reason
        }
        if restoreWhenFull {
            return "restores at 100%"
        }
        if restoreOnUnplug {
            return "restores when unplugged"
        }
        return "restores automatically"
    }

    public var restorePhrase: String {
        if restoreWhenFull {
            return "once it reaches 100%"
        }
        if restoreOnUnplug {
            return "when you unplug your Mac"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: deadline, relativeTo: Date())
    }
}

public struct AlertThresholds: Codable, Equatable, Sendable {
    public var notifyWhenLimitReached: Bool
    public var notifyOnWarmBattery: Bool
    public var warmThresholdCelsius: Double
    public var notifyOnHeavyPluggedInHours: Bool
    public var maxHoursAbove80PerDay: Double
    public var notifyOnOvernightSleepDrain: Bool
    public var sleepDrainPercentThreshold: Int
    public var notifyOnLowDeviceBattery: Bool
    public var lowDevicePercentThreshold: Int

    public init(
        notifyWhenLimitReached: Bool = true,
        notifyOnWarmBattery: Bool = true,
        warmThresholdCelsius: Double = 38.0,
        notifyOnHeavyPluggedInHours: Bool = true,
        maxHoursAbove80PerDay: Double = 6.0,
        notifyOnOvernightSleepDrain: Bool = true,
        sleepDrainPercentThreshold: Int = 10,
        notifyOnLowDeviceBattery: Bool = true,
        lowDevicePercentThreshold: Int = 20
    ) {
        self.notifyWhenLimitReached = notifyWhenLimitReached
        self.notifyOnWarmBattery = notifyOnWarmBattery
        self.warmThresholdCelsius = warmThresholdCelsius
        self.notifyOnHeavyPluggedInHours = notifyOnHeavyPluggedInHours
        self.maxHoursAbove80PerDay = maxHoursAbove80PerDay
        self.notifyOnOvernightSleepDrain = notifyOnOvernightSleepDrain
        self.sleepDrainPercentThreshold = sleepDrainPercentThreshold
        self.notifyOnLowDeviceBattery = notifyOnLowDeviceBattery
        self.lowDevicePercentThreshold = lowDevicePercentThreshold
    }
}
