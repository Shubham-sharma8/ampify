import Foundation
import IOKit
import IOKit.ps
#if canImport(AmpifyBridge)
import AmpifyBridge
#endif

public final class IOKitBatterySource: @unchecked Sendable {
    public static let shared = IOKitBatterySource()

    public init() {}

    public func readCurrent() -> BatteryReading {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        defer {
            if service != IO_OBJECT_NULL {
                IOObjectRelease(service)
            }
        }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard service != IO_OBJECT_NULL,
              IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = propsRef?.takeRetainedValue() as? [String: Any] else {
            return BatteryReading()
        }

        let currentCap = dict["CurrentCapacity"] as? Int ?? 0
        let maxCap = dict["MaxCapacity"] as? Int ?? 100
        let rawCurrentCap = dict["AppleRawCurrentCapacity"] as? Int ?? currentCap
        let rawMaxCap = dict["AppleRawMaxCapacity"] as? Int ?? (dict["NominalChargeCapacity"] as? Int ?? 4500)
        let nominalCap = dict["NominalChargeCapacity"] as? Int ?? rawMaxCap
        let designCap = dict["DesignCapacity"] as? Int ?? max(nominalCap, 4500)
        let cycleCount = dict["CycleCount"] as? Int ?? 0
        let designCycles = dict["DesignCycleCount9C"] as? Int ?? 1000

        let percentage: Int = {
            if maxCap > 0 && maxCap <= 100 {
                return min(100, max(0, currentCap))
            }
            if rawMaxCap > 0 {
                return min(100, max(0, Int((Double(rawCurrentCap) / Double(rawMaxCap) * 100.0).rounded())))
            }
            return 80
        }()

        let healthPercent: Int = {
            guard designCap > 0 else { return 100 }
            let ratio = (Double(nominalCap) / Double(designCap)) * 100.0
            return min(100, max(10, Int(ratio.rounded())))
        }()

        let isPluggedIn = (dict["ExternalConnected"] as? Bool) ?? false
        let isCharging = (dict["IsCharging"] as? Bool) ?? false
        let isFullyCharged = (dict["FullyCharged"] as? Bool) ?? (percentage >= 100)

        let rawTemp = dict["Temperature"] as? Int ?? 2940
        let tempC: Double = rawTemp > 2000
            ? (Double(rawTemp) / 100.0)
            : (Double(rawTemp) / 10.0 - 273.15)
        let clampedTempC = min(75.0, max(10.0, tempC))

        let voltageMV = dict["Voltage"] as? Int ?? 12000
        let voltageV = Double(voltageMV) / 1000.0

        let amperageMA = dict["InstantAmperage"] as? Int ?? (dict["Amperage"] as? Int ?? 0)
        let amperageA = Double(amperageMA) / 1000.0
        let batteryWatts = abs(voltageV * amperageA)

        var adapterWatts: Int? = nil
        if let adapterDetails = dict["AdapterDetails"] as? [String: Any],
           let watts = adapterDetails["Watts"] as? Int, watts > 0 {
            adapterWatts = watts
        }

        var sysPowerIn: Double? = nil
        var sysLoad: Double? = nil
        var thermalSeconds: Int? = nil
        if let telemetry = dict["PowerTelemetryData"] as? [String: Any] {
            if let pIn = telemetry["SystemPowerIn"] as? Int {
                sysPowerIn = Double(pIn) / 1000.0
            }
            if let pLoad = telemetry["SystemLoad"] as? Int {
                sysLoad = Double(pLoad) / 1000.0
            }
            if let therm = telemetry["TimeChargingThermallyLimited"] as? Int {
                thermalSeconds = therm
            }
        }

        let timeRemaining: Int? = {
            if let tr = dict["TimeRemaining"] as? Int, tr > 0 && tr < 60000 {
                return tr
            }
            let psEstimate = IOPSGetTimeRemainingEstimate()
            if psEstimate > 0 && psEstimate != kIOPSTimeRemainingUnknown && psEstimate != kIOPSTimeRemainingUnlimited {
                return Int(psEstimate / 60.0)
            }
            return nil
        }()

        let notChargingCode = dict["NotChargingReason"] as? Int
        let slowChargingCode = dict["SlowChargingReason"] as? Int

        let supported = ChargeLimitBridge.isSupported()
        let unavailableReason = supported ? nil : (try? ChargeLimitBridge.unavailableReason())
        let bridgeActive = Int(ChargeLimitBridge.activeLimit())
        let bridgeStored = Int(ChargeLimitBridge.storedLimit())
        let debug = ChargeLimitBridge.debugInfo()
        let obcEngaged = (debug["obcEngaged"] as? NSNumber)?.boolValue ?? false
        let maxChargeLimited = (debug["maxChargeLimited"] as? NSNumber)?.boolValue ?? (bridgeActive > 0)

        let activeLimit: Int? = (bridgeActive > 0 && bridgeActive < 100) ? bridgeActive : nil
        let storedLimit: Int = (bridgeStored > 0 && bridgeStored < 100) ? bridgeStored : 80

        return BatteryReading(
            timestamp: Date(),
            percentage: percentage,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            isFullyCharged: isFullyCharged,
            activeChargeLimit: activeLimit,
            storedChargeLimit: storedLimit,
            isLimitSupported: supported,
            limitUnavailableReason: unavailableReason,
            healthPercent: healthPercent,
            nominalCapacitymAh: nominalCap,
            rawMaxCapacitymAh: rawMaxCap,
            designCapacitymAh: max(designCap, nominalCap),
            currentCapacitymAh: rawCurrentCap > 100 ? rawCurrentCap : Int(Double(nominalCap) * Double(percentage) / 100.0),
            cycleCount: cycleCount,
            designCycleCount: designCycles,
            temperatureCelsius: clampedTempC,
            voltageVolts: voltageV,
            amperageAmps: amperageA,
            batteryWatts: batteryWatts,
            systemPowerInWatts: sysPowerIn,
            systemLoadWatts: sysLoad,
            adapterWatts: adapterWatts,
            timeRemainingMinutes: timeRemaining,
            notChargingReasonCode: notChargingCode,
            slowChargingReasonCode: slowChargingCode,
            thermallyLimitedSeconds: thermalSeconds,
            obcEngaged: obcEngaged,
            maxChargeLimited: maxChargeLimited
        )
    }

    public static func currentHardwareModelIdentifier() -> String {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac15,12" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}
