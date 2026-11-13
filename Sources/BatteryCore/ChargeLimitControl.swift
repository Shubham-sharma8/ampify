import Foundation
#if canImport(AmpifyBridge)
import AmpifyBridge
#endif

public struct PowerUIChargeLimit: Sendable {
    public static func isSupported() -> Bool {
        ChargeLimitBridge.isSupported()
    }

    public static func unavailableReason() -> String? {
        try? ChargeLimitBridge.unavailableReason()
    }

    public static func activeLimit() -> Int? {
        let val = Int(ChargeLimitBridge.activeLimit())
        return (val > 0 && val < 100) ? val : nil
    }

    public static func storedLimit() -> Int {
        let val = Int(ChargeLimitBridge.storedLimit())
        return (val > 0 && val < 100) ? val : 80
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) throws -> Bool {
        try ChargeLimitBridge.setEnabled(enabled)
        return true
    }

    @discardableResult
    public static func beginTemporaryFullCharge() throws -> Bool {
        try ChargeLimitBridge.beginTemporaryFullCharge()
        return true
    }
}

public struct LimitWatchdog: Sendable {
    public enum Status: Equatable, Sendable {
        case inactive
        case holding(limit: Int)
        case chargingTowardLimit(limit: Int)
        case pausedAboveLimit(limit: Int)
        case temporaryFullCharge
        case overshootSuspected(limit: Int)
    }

    public enum SlipCause: String, CaseIterable, Identifiable, Sendable {
        case calibration
        case sleepOrClamshell
        case systemUpdateOrRestart

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .calibration:
                return "Battery gauge calibration"
            case .sleepOrClamshell:
                return "Charging during deep sleep or power off"
            case .systemUpdateOrRestart:
                return "Recent macOS update or SMC reset"
            }
        }

        public var explanation: String {
            switch self {
            case .calibration:
                return "Every few weeks macOS briefly charges to 100% so the percentage reading does not drift, then returns to 80% on its own."
            case .sleepOrClamshell:
                return "While your Mac is powered off or in deep sleep before login, macOS powerd may temporarily allow charging past the limit."
            case .systemUpdateOrRestart:
                return "After a macOS update, powerd can reset the Manual Charge Limit flag until Ampify re-applies it."
            }
        }
    }

    public static func evaluate(
        reading: BatteryReading,
        userWantsLimit: Bool,
        fullChargeSession: FullChargeSession?
    ) -> Status {
        if fullChargeSession != nil {
            return .temporaryFullCharge
        }
        let targetLimit = reading.activeChargeLimit ?? (userWantsLimit ? reading.storedChargeLimit : nil)
        guard let limit = targetLimit, limit < 100 else {
            return .inactive
        }

        if reading.isPluggedIn {
            if reading.isCharging && reading.percentage > limit + 2 {
                return .overshootSuspected(limit: limit)
            }
            if reading.percentage > limit + 3 && reading.activeChargeLimit == nil && userWantsLimit {
                return .overshootSuspected(limit: limit)
            }
            if !reading.isCharging && abs(reading.percentage - limit) <= 2 {
                return .holding(limit: limit)
            }
            if !reading.isCharging && reading.percentage > limit {
                return .pausedAboveLimit(limit: limit)
            }
            if reading.isCharging && reading.percentage <= limit {
                return .chargingTowardLimit(limit: limit)
            }
        }
        return .holding(limit: limit)
    }
}

public struct CalibrationDetector: Sendable {
    public struct ProbeResult: Equatable, Sendable {
        public var isCalibrating: Bool
        public var lastChecked: Date
        public var matchedMessage: String?

        public init(isCalibrating: Bool = false, lastChecked: Date = Date(), matchedMessage: String? = nil) {
            self.isCalibrating = isCalibrating
            self.lastChecked = lastChecked
            self.matchedMessage = matchedMessage
        }
    }

    public static func probePowerdLogs() -> ProbeResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--last", "30m",
            "--style", "compact",
            "--predicate",
            #"process == "powerd" AND (category == "batterygauging" OR eventMessage CONTAINS "ChargingUpForGauging" OR eventMessage CONTAINS "mitigations are in place")"#
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output
                    .split(separator: "\n")
                    .map(String.init)
                    .filter { $0.contains("ChargingUpForGauging") || $0.contains("batterygauging") }
                if let last = lines.last {
                    let active = last.contains("ChargingUpForGauging: 1") || last.contains("ChargingUpForGauging=1") || last.contains("mitigations are in place")
                    return ProbeResult(isCalibrating: active, lastChecked: Date(), matchedMessage: last)
                }
            }
        } catch {
            // Fall back cleanly if log show is unavailable
        }
        return ProbeResult(isCalibrating: false, lastChecked: Date(), matchedMessage: nil)
    }
}
