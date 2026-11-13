import Foundation
import AppKit
import Darwin
import IOKit.pwr_mgt

// MARK: - Per-App Live Energy Monitor (proc_pid_rusage)

public struct AppEnergyEntry: Identifiable, Codable, Equatable, Sendable {
    public enum ActivityBand: String, Codable, Sendable {
        case workingHard = "Working hard"
        case busy = "Active"
        case light = "Light"
        case idle = "Idle"
    }

    public enum EntryKind: String, Codable, Sendable {
        case application
        case macOSItself
        case everythingElse
    }

    public var id: String { "\(kind.rawValue)-\(pid)-\(name)" }
    public var pid: pid_t
    public var bundleIdentifier: String?
    public var name: String
    public var watts: Double
    public var cpuPercent: Double
    public var extraMinutesIfQuit: Int?
    public var kind: EntryKind

    public var activityBand: ActivityBand {
        if watts >= 3.5 { return .workingHard }
        if watts >= 1.0 { return .busy }
        if watts >= 0.35 { return .light }
        return .idle
    }

    public var stateLabel: String? {
        switch kind {
        case .everythingElse:
            return nil
        case .macOSItself, .application:
            return activityBand.rawValue
        }
    }

    public var quitGainText: String? {
        guard kind == .application, let mins = extraMinutesIfQuit, mins >= 5 else { return nil }
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "About \(h)h \(m)m more if you quit it" : "About \(h)h more if you quit it"
        }
        return "About \(mins) min more if you quit it"
    }

    public init(
        pid: pid_t,
        bundleIdentifier: String?,
        name: String,
        watts: Double,
        cpuPercent: Double,
        extraMinutesIfQuit: Int?,
        kind: EntryKind = .application
    ) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.watts = watts
        self.cpuPercent = cpuPercent
        self.extraMinutesIfQuit = extraMinutesIfQuit
        self.kind = kind
    }
}

public final class RusageEnergyMonitor: @unchecked Sendable {
    private struct Snapshot {
        let timestamp: TimeInterval
        let cpuNanoseconds: UInt64
        let energyNanojoules: UInt64
    }

    private var previousByPid: [pid_t: Snapshot] = [:]
    private var timebaseNumer: UInt32 = 1
    private var timebaseDenom: UInt32 = 1

    public init() {
        var info = mach_timebase_info_data_t()
        if mach_timebase_info(&info) == KERN_SUCCESS, info.denom > 0 {
            timebaseNumer = info.numer
            timebaseDenom = info.denom
        }
    }

    public func sampleTopApps(currentReading: BatteryReading, limit: Int = 4) -> [AppEnergyEntry] {
        let now = ProcessInfo.processInfo.systemUptime
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            app.processIdentifier > 0 &&
            app.activationPolicy == .regular &&
            app.bundleIdentifier != Bundle.main.bundleIdentifier &&
            app.localizedName != "Finder"
        }

        var nextSnapshots: [pid_t: Snapshot] = [:]
        var appEntries: [AppEnergyEntry] = []

        for app in runningApps {
            let pid = app.processIdentifier
            var usage = rusage_info_v6()
            let rc = withUnsafeMutablePointer(to: &usage) { ptr -> Int32 in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, rebound)
                }
            }
            guard rc == 0 else { continue }

            let totalMachTicks = usage.ri_user_time &+ usage.ri_system_time
            let cpuNs = (totalMachTicks &* UInt64(timebaseNumer)) / UInt64(max(1, timebaseDenom))
            let energyNj = usage.ri_energy_nj

            let snap = Snapshot(timestamp: now, cpuNanoseconds: cpuNs, energyNanojoules: energyNj)
            nextSnapshots[pid] = snap

            let measuredWatts: Double
            let cpuPct: Double
            if let prev = previousByPid[pid] {
                let dt = max(0.25, now - prev.timestamp)
                let dCpuNs = cpuNs >= prev.cpuNanoseconds ? (cpuNs - prev.cpuNanoseconds) : 0
                cpuPct = (Double(dCpuNs) / 1_000_000_000.0 / dt) * 100.0

                let dEnergyNj = energyNj >= prev.energyNanojoules ? (energyNj - prev.energyNanojoules) : 0
                if dEnergyNj > 0 {
                    measuredWatts = max(0.05, Double(dEnergyNj) / 1_000_000_000.0 / dt)
                } else {
                    measuredWatts = max(0.05, cpuPct * 0.085 + (app.isActive ? 0.12 : 0.04))
                }
            } else {
                // Initial baseline estimate before second delta arrives
                cpuPct = app.isActive ? 1.8 : 0.4
                measuredWatts = app.isActive ? 0.22 : 0.08
            }

            var extraMinutes: Int? = nil
            if !currentReading.isPluggedIn,
               let currentRemaining = currentReading.timeRemainingMinutes,
               currentRemaining > 10,
               measuredWatts >= 0.4 {
                let totalDraw = max(4.0, currentReading.batteryWatts > 1.0 ? currentReading.batteryWatts : 11.0)
                let clampedAppW = min(totalDraw * 0.65, measuredWatts)
                let newDraw = max(3.0, totalDraw - clampedAppW)
                let projectedRemaining = Double(currentRemaining) * (totalDraw / newDraw)
                let gain = Int((projectedRemaining - Double(currentRemaining)).rounded())
                if gain >= 5 {
                    extraMinutes = min(180, gain)
                }
            }

            appEntries.append(
                AppEnergyEntry(
                    pid: pid,
                    bundleIdentifier: app.bundleIdentifier,
                    name: app.localizedName ?? "App (\(pid))",
                    watts: measuredWatts,
                    cpuPercent: cpuPct,
                    extraMinutesIfQuit: extraMinutes,
                    kind: .application
                )
            )
        }

        previousByPid = nextSnapshots

        let sortedApps = appEntries.sorted { a, b in
            if abs(a.watts - b.watts) > 0.03 {
                return a.watts > b.watts
            }
            return a.name < b.name
        }

        let topRealApps = Array(sortedApps.prefix(max(2, limit)))
        let remainingAppsWatts = sortedApps.dropFirst(topRealApps.count).map(\.watts).reduce(0.0, +)
        let topSum = topRealApps.map(\.watts).reduce(0.0, +)

        // Include synthetic rows for "macOS itself" and "Everything else" so the power breakdown is always complete
        let macOSWatts = max(0.1, min(1.8, (currentReading.systemLoadWatts ?? 4.0) * 0.035))
        let everythingElseWatts = max(0.1, remainingAppsWatts > 0.05 ? remainingAppsWatts : max(0.1, topSum * 0.25))

        var finalEntries = topRealApps
        finalEntries.append(
            AppEnergyEntry(
                pid: -1,
                bundleIdentifier: "com.apple.finder",
                name: "macOS itself",
                watts: (macOSWatts * 10).rounded() / 10.0,
                cpuPercent: 1.2,
                extraMinutesIfQuit: nil,
                kind: .macOSItself
            )
        )
        finalEntries.append(
            AppEnergyEntry(
                pid: -2,
                bundleIdentifier: nil,
                name: "Everything else",
                watts: (everythingElseWatts * 10).rounded() / 10.0,
                cpuPercent: 0.8,
                extraMinutesIfQuit: nil,
                kind: .everythingElse
            )
        )

        return finalEntries
    }
}

// MARK: - What's Keeping Your Mac Awake (IOPMCopyAssertionsByProcess)

public struct AwakeAssertionHolder: Identifiable, Equatable, Sendable {
    public enum Category: String, Sendable {
        case video = "Playing video"
        case call = "Call or meeting"
        case audio = "Playing audio"
        case terminal = "Terminal / caffeinate"
        case background = "Background task"

        public var sfSymbol: String {
            switch self {
            case .video: return "play.rectangle"
            case .call: return "video"
            case .audio: return "speaker.wave.2"
            case .terminal: return "terminal"
            case .background: return "gearshape"
            }
        }
    }

    public var id: String { "\(pid)-\(assertionName)" }
    public var pid: Int
    public var processName: String
    public var assertionType: String
    public var assertionName: String
    public var category: Category
    public var heldDurationSeconds: Int

    public var formattedDuration: String {
        if heldDurationSeconds < 60 {
            return "<1m"
        }
        let mins = heldDurationSeconds / 60
        if mins < 60 {
            return "\(mins)m"
        }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

public enum AwakeHoldersScanner {
    public static func currentHolders(excludingOwnPID: Bool = true) -> [AwakeAssertionHolder] {
        var assertionsByPidRef: Unmanaged<CFDictionary>?
        let status = IOPMCopyAssertionsByProcess(&assertionsByPidRef)
        guard status == kIOReturnSuccess,
              let cfDict = assertionsByPidRef?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else {
            return []
        }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        let now = Date()
        var results: [AwakeAssertionHolder] = []

        for (pidNum, assertionList) in cfDict {
            let pid = pidNum.intValue
            if excludingOwnPID && pid == ownPID { continue }

            for item in assertionList {
                let type = (item["AssertType"] as? String) ?? ""
                guard type == "PreventUserIdleSystemSleep" ||
                      type == "PreventUserIdleDisplaySleep" ||
                      type == "NoDisplaySleepAssertion" ||
                      type == "NoIdleSleepAssertion" else {
                    continue
                }

                let rawProcess = (item["Process Name"] as? String) ?? "Process \(pid)"
                if ["powerd", "WindowServer", "loginwindow", "coreaudiod"].contains(rawProcess) {
                    continue
                }
                let reason = (item["AssertName"] as? String) ?? "Keeping Mac awake"
                let startDate = item["AssertionStartWhen"] as? Date
                let durationSec = startDate.map { max(1, Int(now.timeIntervalSince($0))) } ?? 60

                let lowered = "\(rawProcess) \(reason)".lowercased()
                let category: AwakeAssertionHolder.Category
                if lowered.contains("zoom") || lowered.contains("meet") || lowered.contains("teams") || lowered.contains("facetime") || lowered.contains("call") {
                    category = .call
                } else if lowered.contains("video") || lowered.contains("youtube") || lowered.contains("quicktime") || lowered.contains("iina") || lowered.contains("vlc") || type.contains("Display") {
                    category = .video
                } else if lowered.contains("caffeinate") || lowered.contains("terminal") || lowered.contains("iterm") {
                    category = .terminal
                } else if lowered.contains("audio") || lowered.contains("music") || lowered.contains("spotify") {
                    category = .audio
                } else {
                    category = .background
                }

                results.append(
                    AwakeAssertionHolder(
                        pid: pid,
                        processName: rawProcess,
                        assertionType: type,
                        assertionName: reason,
                        category: category,
                        heldDurationSeconds: durationSec
                    )
                )
            }
        }

        return results.sorted { $0.heldDurationSeconds > $1.heldDurationSeconds }
    }
}

// MARK: - Sleep Drain Tracker

public struct SleepDrainEpisode: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sleptAt: Date
    public var wokeAt: Date
    public var startPercent: Int
    public var endPercent: Int
    public var darkWakeCount: Int

    public var durationHours: Double {
        max(0.1, wokeAt.timeIntervalSince(sleptAt) / 3600.0)
    }

    public var drainPercent: Int {
        max(0, startPercent - endPercent)
    }

    public var percentPerHour: Double {
        Double(drainPercent) / durationHours
    }

    public var summaryLine: String {
        let hrs = String(format: "%.1f hr", durationHours)
        if drainPercent == 0 {
            return "Slept \(hrs) · 0% battery lost"
        }
        return "Slept \(hrs) · lost \(drainPercent)% (\(String(format: "%.1f%%/hr", percentPerHour)))"
    }

    public init(
        id: UUID = UUID(),
        sleptAt: Date,
        wokeAt: Date,
        startPercent: Int,
        endPercent: Int,
        darkWakeCount: Int = 0
    ) {
        self.id = id
        self.sleptAt = sleptAt
        self.wokeAt = wokeAt
        self.startPercent = startPercent
        self.endPercent = endPercent
        self.darkWakeCount = darkWakeCount
    }
}

// MARK: - Power Switches (Keep Awake & Low Power Mode)

public enum KeepAwakeDuration: String, CaseIterable, Codable, Sendable {
    case off = "Off"
    case oneHour = "For 1 Hour"
    case twoHours = "For 2 Hours"
    case indefinite = "Until Turned Off"

    public var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .oneHour: return 3600
        case .twoHours: return 7200
        case .indefinite: return nil
        }
    }
}

public final class PowerSwitchesController: @unchecked Sendable {
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    public private(set) var activeMode: KeepAwakeDuration = .off
    public private(set) var expiresAt: Date? = nil

    public init() {}

    public func setKeepAwake(_ mode: KeepAwakeDuration) {
        releaseAssertionIfNeeded()
        activeMode = mode
        guard mode != .off else {
            expiresAt = nil
            return
        }

        let reason = "Ampify Keep Awake (\(mode.rawValue))" as CFString
        var newID: IOPMAssertionID = IOPMAssertionID(0)
        let rc = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &newID
        )
        if rc == kIOReturnSuccess {
            assertionID = newID
            if let secs = mode.seconds {
                expiresAt = Date().addingTimeInterval(secs)
            } else {
                expiresAt = nil
            }
        } else {
            activeMode = .off
            expiresAt = nil
        }
    }

    public func evaluateAutoRelease(reading: BatteryReading) {
        guard activeMode != .off else { return }
        if let exp = expiresAt, Date() >= exp {
            setKeepAwake(.off)
            return
        }
        // Auto-release at 10% on battery so the Mac never dies unexpectedly
        if !reading.isPluggedIn && reading.percentage <= 10 {
            setKeepAwake(.off)
        }
    }

    private func releaseAssertionIfNeeded() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }

    deinit {
        releaseAssertionIfNeeded()
    }

    public static func isLowPowerModeEnabled() -> Bool {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return true
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["-g"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            if let text = String(data: data, encoding: .utf8) {
                for line in text.split(separator: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("lowpowermode") || trimmed.hasPrefix("powermode") {
                        return trimmed.hasSuffix("1")
                    }
                }
            }
        } catch {}
        return false
    }

    @discardableResult
    public static func setLowPowerMode(_ enabled: Bool) -> Bool {
        let value = enabled ? "1" : "0"
        let script = "do shell script \"/usr/bin/pmset -a lowpowermode \(value)\" with administrator privileges"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }
}
