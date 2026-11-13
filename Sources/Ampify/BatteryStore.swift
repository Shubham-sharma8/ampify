import Foundation
import SwiftUI
import AppKit
import ServiceManagement
@preconcurrency import UserNotifications
import WidgetKit
#if canImport(BatteryCore)
import BatteryCore
#endif

public enum DashboardSection: String, CaseIterable, Identifiable {
    case now = "Now"
    case health = "Health"
    case habits = "Habits"
    case energy = "Energy"
    case devices = "Devices"
    case widgets = "Widgets"
    case alerts = "Alerts"
    case settings = "Settings"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .now: return "battery.75percent"
        case .health: return "heart"
        case .habits: return "chart.bar"
        case .energy: return "bolt"
        case .devices: return "laptopcomputer.and.iphone"
        case .widgets: return "square.grid.2x2"
        case .alerts: return "bell"
        case .settings: return "gearshape"
        }
    }

    public var subtitle: String {
        switch self {
        case .now: return "Live battery state, power flow & 80% charge limit"
        case .health: return "Capacity trend, cycles & service estimate"
        case .habits: return "Weekly time above 80% & smart top-up"
        case .energy: return "Active apps, awake holders, stretches & sleep drain"
        case .devices: return "iPhone, iPad, Apple Watch & Bluetooth batteries"
        case .widgets: return "macOS Desktop & Notification Center widgets"
        case .alerts: return "Quiet notifications & thresholds"
        case .settings: return "Menu bar style, language level, diagnostics & about"
        }
    }
}

public struct AlertLogEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var timestamp: Date
    public var title: String
    public var message: String
}

@MainActor
public final class BatteryStore: ObservableObject {
    public static let shared = BatteryStore()

    // Core state
    @Published public var reading: BatteryReading
    @Published public var limitEnabled: Bool
    @Published public var fullChargeSession: FullChargeSession?
    @Published public var limitStatus: LimitWatchdog.Status = .inactive
    @Published public var calibrationProbe: CalibrationDetector.ProbeResult = CalibrationDetector.ProbeResult()
    @Published public var statusExplanation: StatusExplanation
    @Published public var powerFlow: PowerFlowSnapshot
    @Published public var biggestSeenChargerWatts: Int
    @Published public var activeInsight: BatteryInsight?
    @Published public var lastStatusError: String?

    // Preferences
    @Published public var detailLevel: DetailLevel {
        didSet { UserDefaults.standard.set(detailLevel.rawValue, forKey: "ampify.detailLevel") }
    }
    @Published public var menuBarStyle: MenuBarStyle {
        didSet { UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "ampify.menuBarStyle") }
    }
    @Published public var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "ampify.hasCompletedOnboarding") }
    }
    @Published public var selectedRegionCode: String {
        didSet {
            UserDefaults.standard.set(selectedRegionCode, forKey: "ampify.regionCode")
            serviceEstimate = BatteryServiceCatalog.estimate(regionCode: selectedRegionCode)
        }
    }

    // Smart Top-Up preferences
    @Published public var tripTopUpEnabled: Bool {
        didSet { UserDefaults.standard.set(tripTopUpEnabled, forKey: "ampify.tripTopUpEnabled") }
    }
    @Published public var tripIncludeAllDayEvents: Bool {
        didSet { UserDefaults.standard.set(tripIncludeAllDayEvents, forKey: "ampify.tripIncludeAllDayEvents") }
    }
    @Published public var tripKeywordsText: String {
        didSet { UserDefaults.standard.set(tripKeywordsText, forKey: "ampify.tripKeywordsText") }
    }
    @Published public var smartDepartureTopUpEnabled: Bool {
        didSet { UserDefaults.standard.set(smartDepartureTopUpEnabled, forKey: "ampify.smartDepartureTopUpEnabled") }
    }

    // History, Health, Habits & Stretches
    @Published public var recentHistory: [HistoryPoint] = []
    @Published public var dailyHighChargeBuckets: [DailyHighChargeBucket] = []
    @Published public var weekSummary: WeekSummary
    @Published public var healthSamples: [HealthSample] = []
    @Published public var healthTimeRange: HealthTimeRange = .ninetyDays
    @Published public var healthProjection: HealthProjection
    @Published public var serviceEstimate: BatteryServiceEstimate
    @Published public var batteryStretches: [BatteryStretch] = []

    // Energy, Awake Holders, Sleep Drain & Power Switches
    @Published public var topEnergyApps: [AppEnergyEntry] = []
    @Published public var awakeHolders: [AwakeAssertionHolder] = []
    @Published public var sleepEpisodes: [SleepDrainEpisode] = []
    @Published public var keepAwakeDuration: KeepAwakeDuration = .off
    @Published public var lowPowerModeEnabled: Bool = false

    // Connected Devices & Smart Top-Up
    @Published public var appleDevices: [ConnectedAppleDevice] = []
    @Published public var bluetoothAccessories: [BluetoothAccessoryBattery] = []
    @Published public var nearbyBluetoothAppleNames: [String] = []
    @Published public var isScanningDevices: Bool = false
    @Published public var showAddDeviceGuide: Bool = false
    @Published public var upcomingTrips: [CalendarTripMatch] = []
    @Published public var departurePredictions: [DeparturePrediction] = []

    // Widgets, Diagnostics & Navigation
    @Published public var latestWidgetSnapshot: WidgetSnapshot = WidgetSnapshot()
    @Published public var showDiagnosticsSheet: Bool = false
    @Published public var alertThresholds: AlertThresholds {
        didSet { saveCodable(alertThresholds, key: "ampify.alertThresholds") }
    }
    @Published public var alertLog: [AlertLogEntry] = []
    @Published public var selectedSection: DashboardSection = .now
    @Published public var showOnboardingSheet: Bool = false

    private let batterySource = IOKitBatterySource.shared
    private let energyMonitor = RusageEnergyMonitor()
    private let powerSwitches = PowerSwitchesController()
    private let calendarScanner = EventKitCalendarScanner()
    private var pollTimer: Timer?
    private var devicePollTimer: Timer?
    private var lastSampledDate: Date?
    private var sleepStartedAt: Date?
    private var sleepStartPercent: Int?

    public init() {
        let initialReading = IOKitBatterySource.shared.readCurrent()
        self.reading = initialReading

        let storedLimitPref = UserDefaults.standard.object(forKey: "ampify.limitEnabled") as? Bool
        let initialLimitEnabled = storedLimitPref ?? (initialReading.activeChargeLimit != nil)
        self.limitEnabled = initialLimitEnabled

        let rawDetail = UserDefaults.standard.string(forKey: "ampify.detailLevel") ?? DetailLevel.simple.rawValue
        self.detailLevel = DetailLevel(rawValue: rawDetail) ?? .simple

        let rawMenu = UserDefaults.standard.string(forKey: "ampify.menuBarStyle") ?? MenuBarStyle.percent.rawValue
        self.menuBarStyle = MenuBarStyle(rawValue: rawMenu) ?? .percent

        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "ampify.hasCompletedOnboarding")

        let defaultRegion = Locale.current.region?.identifier ?? "US"
        let savedRegion = UserDefaults.standard.string(forKey: "ampify.regionCode") ?? defaultRegion
        self.selectedRegionCode = ["US", "CA", "GB", "DE", "FR", "JP"].contains(savedRegion) ? savedRegion : "US"

        let savedBiggestW = UserDefaults.standard.integer(forKey: "ampify.biggestChargerWatts")
        let initialBiggestW = max(savedBiggestW > 0 ? savedBiggestW : 67, initialReading.adapterWatts ?? 67)
        self.biggestSeenChargerWatts = initialBiggestW
        self.powerFlow = PowerFlowSnapshot.compute(from: initialReading, biggestSeenWatts: initialBiggestW)

        self.tripTopUpEnabled = UserDefaults.standard.object(forKey: "ampify.tripTopUpEnabled") as? Bool ?? true
        self.tripIncludeAllDayEvents = UserDefaults.standard.bool(forKey: "ampify.tripIncludeAllDayEvents")
        self.tripKeywordsText = UserDefaults.standard.string(forKey: "ampify.tripKeywordsText")
            ?? EventKitCalendarScanner.defaultKeywords.joined(separator: ", ")
        self.smartDepartureTopUpEnabled = UserDefaults.standard.object(forKey: "ampify.smartDepartureTopUpEnabled") as? Bool ?? true

        self.alertThresholds = Self.loadCodable(key: "ampify.alertThresholds") ?? AlertThresholds()

        let initialWatchdog = LimitWatchdog.evaluate(
            reading: initialReading,
            userWantsLimit: initialLimitEnabled,
            fullChargeSession: nil
        )
        self.limitStatus = initialWatchdog
        self.statusExplanation = StatusExplanation.explain(
            reading: initialReading,
            limitStatus: initialWatchdog,
            fullChargeSession: nil,
            recalibrating: false
        )

        self.serviceEstimate = BatteryServiceCatalog.estimate(regionCode: savedRegion)
        self.weekSummary = WeekSummary.compute(from: [])
        self.healthProjection = HealthProjection.analyze(samples: [], currentReading: initialReading)

        // Load previously discovered paired iOS/watchOS devices so they appear immediately
        if let cachedDevices: [ConnectedAppleDevice] = Self.loadCodable(key: "ampify.appleDevices") {
            self.appleDevices = cachedDevices.filter { $0.udid != "00008112-001420911AA2401B" }
        }

        seedOrLoadHistoricalLedgers(current: initialReading)
        setupWorkspaceSleepObservers()
        if !CommandLine.arguments.contains("--render-marketing") {
            refreshAll()
            startPolling()
        }
    }

    // MARK: - Polling & Refresh

    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLiveState()
            }
        }
        devicePollTimer?.invalidate()
        devicePollTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDevicesInBackground()
            }
        }
    }

    public func refreshAll() {
        refreshLiveState()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            self.topEnergyApps = self.energyMonitor.sampleTopApps(currentReading: self.reading)
        }
        refreshDevicesInBackground()
        refreshCalendarTrips()
    }

    public func refreshLiveState() {
        let previousPlugged = reading.isPluggedIn
        let current = batterySource.readCurrent()
        reading = current

        if let adapterW = current.adapterWatts, adapterW > biggestSeenChargerWatts {
            biggestSeenChargerWatts = adapterW
            UserDefaults.standard.set(adapterW, forKey: "ampify.biggestChargerWatts")
        }
        powerFlow = PowerFlowSnapshot.compute(from: current, biggestSeenWatts: biggestSeenChargerWatts)

        if let session = fullChargeSession {
            if Date() >= session.deadline ||
               (session.restoreOnUnplug && previousPlugged && !current.isPluggedIn) ||
               (session.restoreWhenFull && current.percentage >= 100) {
                endFullChargeSession()
            }
        }

        if previousPlugged && !current.isPluggedIn {
            recordUnplugDepartureEvent()
        }

        limitStatus = LimitWatchdog.evaluate(
            reading: current,
            userWantsLimit: limitEnabled,
            fullChargeSession: fullChargeSession
        )
        if case .overshootSuspected = limitStatus {
            calibrationProbe = CalibrationDetector.probePowerdLogs()
        }
        statusExplanation = StatusExplanation.explain(
            reading: current,
            limitStatus: limitStatus,
            fullChargeSession: fullChargeSession,
            recalibrating: calibrationProbe.isCalibrating
        )

        appendHistoryPoint(from: current)
        updateDailyHighChargeLedger(with: current)
        updateHealthLedger(with: current)

        topEnergyApps = energyMonitor.sampleTopApps(currentReading: current)
        awakeHolders = AwakeHoldersScanner.currentHolders()
        powerSwitches.evaluateAutoRelease(reading: current)
        keepAwakeDuration = powerSwitches.activeMode
        lowPowerModeEnabled = PowerSwitchesController.isLowPowerModeEnabled()

        activeInsight = evaluateInsight(for: current)
        syncWidgetSnapshot()
        evaluateAlerts(for: current)
    }

    // MARK: - Widget Synchronization & Ecosystem Device Slots

    public var healthStatusSubtitle: String {
        if reading.healthPercent >= 85 {
            return "Normal wear, nothing to do."
        }
        if reading.healthPercent >= 80 {
            return "Approaching Apple's 80% service line."
        }
        return "Below 80% — battery service recommended."
    }

    public var ecosystemDeviceSlots: [EcosystemDeviceSlot] {
        var slots: [EcosystemDeviceSlot] = []

        // 1. Real paired iPhone, iPad & Apple Watch discovered over Wi-Fi / USB / CompanionProxy
        for dev in appleDevices {
            let category: EcosystemDeviceSlot.Category
            let shortLabel: String
            switch dev.kind {
            case .iPhone:
                category = .iPhone
                shortLabel = "iPhone"
            case .iPad:
                category = .iPad
                shortLabel = "iPad"
            case .appleWatch:
                category = .appleWatch
                shortLabel = "Watch"
            }
            slots.append(
                EcosystemDeviceSlot(
                    id: dev.udid,
                    name: dev.name,
                    shortLabel: shortLabel,
                    category: category,
                    percent: dev.batteryPercent,
                    isCharging: dev.isCharging,
                    isLiveConnected: true,
                    detailText: dev.isCharging ? "Charging" : "Wi-Fi · \(dev.seenAgoText)"
                )
            )
        }

        // 2. Real Bluetooth & HID accessories that report an actual battery percentage
        for acc in bluetoothAccessories {
            guard let pct = acc.primaryPercent, pct > 0 else { continue }
            let category: EcosystemDeviceSlot.Category
            let defaultShort: String
            switch acc.kind {
            case .earbuds, .headphones:
                category = .airPods
                defaultShort = "AirPods"
            case .applePencil:
                category = .applePencil
                defaultShort = "Pencil"
            case .appleTVRemote:
                category = .appleTV
                defaultShort = "Apple TV"
            case .keyboard:
                category = .keyboard
                defaultShort = "Keyboard"
            case .mouse:
                category = .mouse
                defaultShort = acc.name.count <= 10 ? acc.name : "Mouse"
            case .trackpad:
                category = .trackpad
                defaultShort = "Trackpad"
            case .other:
                category = .mouse
                defaultShort = acc.name.count <= 10 ? acc.name : "Bluetooth"
            }
            slots.append(
                EcosystemDeviceSlot(
                    id: acc.id,
                    name: acc.name,
                    shortLabel: defaultShort,
                    category: category,
                    percent: pct,
                    isCharging: (acc.casePercent ?? 0) > 0 && !acc.isConnected,
                    isLiveConnected: acc.isConnected,
                    detailText: acc.detailSummary
                )
            )
        }

        // 3. This Mac (always present with live hardware battery percentage)
        slots.append(
            EcosystemDeviceSlot(
                id: "slot-this-mac",
                name: Host.current().localizedName ?? "This Mac",
                shortLabel: "This Mac",
                category: .mac,
                percent: reading.percentage,
                isCharging: reading.isCharging,
                isLiveConnected: true,
                detailText: statusExplanation.badgeText
            )
        )

        return slots
    }

    public func quitApp(pid: pid_t) {
        guard pid > 0 else { return }
        NSRunningApplication(processIdentifier: pid)?.terminate()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.topEnergyApps = self.energyMonitor.sampleTopApps(currentReading: self.reading)
            self.syncWidgetSnapshot()
        }
    }

    public func syncWidgetSnapshot(persistToDisk: Bool = true) {
        let phone = appleDevices.first(where: { $0.kind == .iPhone || $0.kind == .iPad })
        let watch = appleDevices.first(where: { $0.kind == .appleWatch })
        let powerItems: [WidgetAppPowerItem] = topEnergyApps.prefix(4).map { entry in
            WidgetAppPowerItem(
                name: entry.name,
                stateLabel: entry.stateLabel,
                watts: entry.watts,
                isMacOSRow: entry.kind == .macOSItself,
                isEverythingElseRow: entry.kind == .everythingElse
            )
        }
        let sumWatts = max(0.1, (powerItems.isEmpty ? WidgetAppPowerItem.defaultItems : powerItems).map(\.watts).reduce(0.0, +))
        let powerSub: String
        if sumWatts >= 6.0 {
            powerSub = "Apps are working hard right now."
        } else if sumWatts >= 2.2 {
            powerSub = "Moderate app activity right now."
        } else {
            powerSub = "Nothing is working hard right now."
        }

        let snap = WidgetSnapshot(
            timestamp: Date(),
            percentage: reading.percentage,
            activeLimit: reading.activeChargeLimit,
            isPluggedIn: reading.isPluggedIn,
            isCharging: reading.isCharging,
            badgeText: statusExplanation.badgeText,
            headline: statusExplanation.headline,
            healthPercent: reading.healthPercent,
            cycleCount: reading.cycleCount,
            healthLine: "\(reading.healthPercent)% health · \(reading.cycleCount) cycles",
            healthSubtitle: healthStatusSubtitle,
            hoursAbove80ThisWeek: weekSummary.totalHoursAbove80,
            highChargeLine: String(format: "%.1f hrs above 80%% this week", weekSummary.totalHoursAbove80),
            powerWatts: reading.batteryWatts,
            primaryDeviceName: phone?.name,
            primaryDevicePercent: phone?.batteryPercent,
            watchName: watch?.name,
            watchPercent: watch?.batteryPercent,
            deviceSlots: ecosystemDeviceSlots,
            appPowerItems: powerItems.isEmpty ? WidgetAppPowerItem.defaultItems : powerItems,
            totalAppWatts: sumWatts,
            appPowerSubtitle: powerSub
        )
        latestWidgetSnapshot = snap
        if persistToDisk && !CommandLine.arguments.contains("--render-marketing") {
            WidgetBridge.write(snap)
        }
    }

    // MARK: - Charge Limit & Temporary Full Charge Controls

    public func setChargeLimitEnabled(_ enabled: Bool) {
        lastStatusError = nil
        limitEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "ampify.limitEnabled")
        if enabled {
            fullChargeSession = nil
        }
        do {
            try PowerUIChargeLimit.setEnabled(enabled)
        } catch {
            lastStatusError = error.localizedDescription
        }
        refreshLiveState()
    }

    public func startFullChargeOnce(
        restoreOnUnplug: Bool = true,
        restoreWhenFull: Bool = false,
        hours: Double = 8.0,
        reason: String? = nil
    ) {
        lastStatusError = nil
        let session = FullChargeSession(
            startedAt: Date(),
            deadline: Date().addingTimeInterval(hours * 3600.0),
            restoreOnUnplug: restoreOnUnplug,
            restoreWhenFull: restoreWhenFull,
            reason: reason
        )
        fullChargeSession = session
        do {
            try PowerUIChargeLimit.beginTemporaryFullCharge()
        } catch {
            lastStatusError = error.localizedDescription
        }
        refreshLiveState()
    }

    public func endFullChargeSession() {
        fullChargeSession = nil
        if limitEnabled {
            _ = try? PowerUIChargeLimit.setEnabled(true)
        }
        refreshLiveState()
    }

    // MARK: - Power Switches

    public func setKeepAwake(_ duration: KeepAwakeDuration) {
        powerSwitches.setKeepAwake(duration)
        keepAwakeDuration = powerSwitches.activeMode
        awakeHolders = AwakeHoldersScanner.currentHolders()
    }

    public func toggleLowPowerMode() {
        let target = !lowPowerModeEnabled
        if PowerSwitchesController.setLowPowerMode(target) {
            lowPowerModeEnabled = target
        } else {
            lowPowerModeEnabled = PowerSwitchesController.isLowPowerModeEnabled()
        }
    }

    // MARK: - Connected Devices & Calendar Trips

    public func refreshDevicesInBackground() {
        guard !isScanningDevices else { return }
        isScanningDevices = true
        Task.detached(priority: .userInitiated) {
            let btScan = BluetoothBatteryScanner.scanAll()
            let iosDevices = MobileDeviceScanner.scanPairedDevices(timeout: 3.5)
            await MainActor.run {
                self.bluetoothAccessories = btScan.accessories
                self.nearbyBluetoothAppleNames = btScan.nearbyBluetoothAppleDeviceNames

                if !iosDevices.isEmpty {
                    // Merge fresh Wi-Fi readings with any previously known devices
                    var merged = iosDevices
                    for old in self.appleDevices where !merged.contains(where: { $0.udid == old.udid }) {
                        merged.append(old)
                    }
                    self.appleDevices = merged
                    self.saveCodable(merged, key: "ampify.appleDevices")
                }
                self.isScanningDevices = false
                self.activeInsight = self.evaluateInsight(for: self.reading)
                self.syncWidgetSnapshot()
            }
        }
    }

    public func requestCalendarPermissionAndScan() {
        Task { @MainActor in
            _ = await calendarScanner.requestAccess()
            refreshCalendarTrips()
        }
    }

    public func refreshCalendarTrips() {
        let keywords = tripKeywordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        upcomingTrips = calendarScanner.upcomingTrips(
            keywords: keywords.isEmpty ? EventKitCalendarScanner.defaultKeywords : keywords,
            includeAllDayEvents: tripIncludeAllDayEvents
        )
    }

    // MARK: - Insights & Diagnostics

    private func evaluateInsight(for current: BatteryReading) -> BatteryInsight? {
        if powerFlow.verdict == .slow || powerFlow.verdict == .weak {
            return BatteryInsight(
                kind: .chargerSlower,
                symbol: "powerplug",
                title: powerFlow.verdict.rawValue,
                detail: powerFlow.summaryText,
                actionLabel: "View Power Flow",
                targetSection: DashboardSection.now.rawValue
            )
        }
        if let lowPhone = appleDevices.first(where: { $0.batteryPercent <= 20 && !$0.isCharging }) {
            return BatteryInsight(
                kind: .devicesTip,
                symbol: lowPhone.kind.sfSymbol,
                title: "\(lowPhone.name) is at \(lowPhone.batteryPercent)%",
                detail: "Discovered over Wi-Fi. Plug it in soon to avoid deep discharge.",
                actionLabel: "Open Devices",
                targetSection: DashboardSection.devices.rawValue
            )
        }
        if appleDevices.isEmpty && !nearbyBluetoothAppleNames.isEmpty {
            let names = nearbyBluetoothAppleNames.joined(separator: " & ")
            return BatteryInsight(
                kind: .devicesTip,
                symbol: "iphone.radiowaves.left.and.right",
                title: "\(names) can show live battery here",
                detail: "Paired over Bluetooth. Enable Wi-Fi sync once in Finder or click Scan Now to read battery over Wi-Fi.",
                actionLabel: "Set Up in Devices",
                targetSection: DashboardSection.devices.rawValue
            )
        }
        if !current.isPluggedIn, let top = topEnergyApps.first, top.watts >= 4.0 {
            return BatteryInsight(
                kind: .drainFast,
                symbol: "bolt",
                title: "\(top.name) is drawing \(String(format: "%.1f W", top.watts))",
                detail: top.quitGainText ?? "Quitting heavy background apps stretches battery runtime.",
                actionLabel: "Open Energy",
                targetSection: DashboardSection.energy.rawValue
            )
        }
        return nil
    }

    public var diagnosticsText: String {
        DiagnosticReportBuilder.build(
            reading: reading,
            limitStatus: limitStatus,
            powerFlow: powerFlow,
            appleDevices: appleDevices,
            accessories: bluetoothAccessories
        )
    }

    // MARK: - Shareable Battery Snapshot PNG Export

    public func exportShareableSnapshotCard() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Shareable Battery Snapshot"
        savePanel.nameFieldStringValue = "Ampify-Snapshot.png"
        savePanel.allowedContentTypes = [.png]
        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        let card = BatteryWidgetView(entry: SnapshotEntry(snapshot: latestWidgetSnapshot))
            .frame(width: 360, height: 170)
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        if let nsImage = renderer.nsImage,
           let tiff = nsImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // MARK: - Menu Bar Formatted Title

    public var menuBarText: String {
        switch menuBarStyle {
        case .percent:
            if let limit = reading.activeChargeLimit, limit < 100, reading.isPluggedIn {
                return "\(reading.percentage)% · \(limit)%"
            }
            return "\(reading.percentage)%"
        case .timeLeft:
            if let formatted = reading.formattedTimeRemaining {
                return formatted
            }
            return "\(reading.percentage)%"
        case .watts:
            let sign = reading.isCharging ? "+" : (reading.isPluggedIn ? "" : "-")
            return String(format: "%@%.0fW", sign, reading.batteryWatts)
        case .icon:
            return ""
        }
    }

    public var usualDrainSummary: String {
        guard !batteryStretches.isEmpty else {
            return "Typically ~8.5%/hr (~11.5 hrs on a full charge)"
        }
        let avgPctPerHr = batteryStretches.map(\.percentPerHour).reduce(0, +) / Double(batteryStretches.count)
        let fullHrs = min(22.0, max(3.0, 100.0 / max(1.5, avgPctPerHr)))
        return String(format: "Usual pace: ~%.1f%%/hr (~%.1f hrs on a full charge)", avgPctPerHr, fullHrs)
    }

    // MARK: - Launch at Login

    public var launchAtLoginEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                objectWillChange.send()
            } catch {}
        }
    }

    // MARK: - Ledgers & Persistence

    private func appendHistoryPoint(from current: BatteryReading) {
        let now = Date()
        if let last = recentHistory.last, now.timeIntervalSince(last.timestamp) < 30 {
            return
        }
        let point = HistoryPoint(
            timestamp: now,
            percentage: current.percentage,
            isPluggedIn: current.isPluggedIn,
            isCharging: current.isCharging,
            watts: current.batteryWatts,
            temperatureC: current.temperatureCelsius
        )
        let cutoff = now.addingTimeInterval(-3 * 3600)
        recentHistory = (recentHistory + [point]).filter { $0.timestamp >= cutoff }
        saveCodable(recentHistory, key: "ampify.recentHistory")
    }

    private func updateDailyHighChargeLedger(with current: BatteryReading) {
        let now = Date()
        let elapsedMinutes: Int
        if let prev = lastSampledDate {
            elapsedMinutes = max(0, min(5, Int((now.timeIntervalSince(prev) / 60.0).rounded())))
        } else {
            elapsedMinutes = 0
        }
        if elapsedMinutes > 0 || lastSampledDate == nil {
            lastSampledDate = now
        }

        let key = Self.dateKey(for: now)
        var buckets = dailyHighChargeBuckets
        if let idx = buckets.firstIndex(where: { $0.dateKey == key }) {
            var bucket = buckets[idx]
            if elapsedMinutes > 0 {
                if current.isPluggedIn {
                    bucket.totalPluggedMinutes += elapsedMinutes
                }
                if current.percentage > 80 {
                    if current.isPluggedIn {
                        bucket.pluggedMinutesAbove80 += elapsedMinutes
                    } else {
                        bucket.unpluggedMinutesAbove80 += elapsedMinutes
                    }
                }
            }
            bucket.peakTemperatureC = max(bucket.peakTemperatureC, current.temperatureCelsius)
            buckets[idx] = bucket
        } else {
            let newBucket = DailyHighChargeBucket(
                dateKey: key,
                date: Calendar.current.startOfDay(for: now),
                pluggedMinutesAbove80: (current.percentage > 80 && current.isPluggedIn) ? 15 : 0,
                unpluggedMinutesAbove80: (current.percentage > 80 && !current.isPluggedIn) ? 10 : 0,
                totalPluggedMinutes: current.isPluggedIn ? 45 : 0,
                peakTemperatureC: current.temperatureCelsius
            )
            buckets.append(newBucket)
        }
        dailyHighChargeBuckets = Array(buckets.suffix(14))
        weekSummary = WeekSummary.compute(from: dailyHighChargeBuckets)
        saveCodable(dailyHighChargeBuckets, key: "ampify.dailyHighChargeBuckets")
    }

    private func updateHealthLedger(with current: BatteryReading) {
        let key = Self.dateKey(for: Date())
        var samples = healthSamples
        let sample = HealthSample(
            dateKey: key,
            date: Calendar.current.startOfDay(for: Date()),
            healthPercent: current.healthPercent,
            nominalCapacitymAh: current.nominalCapacitymAh,
            designCapacitymAh: current.designCapacitymAh,
            cycleCount: current.cycleCount
        )
        if let idx = samples.firstIndex(where: { $0.dateKey == key }) {
            samples[idx] = sample
        } else {
            samples.append(sample)
        }
        healthSamples = samples.sorted { $0.date < $1.date }
        healthProjection = HealthProjection.analyze(samples: healthSamples, currentReading: current)
        saveCodable(healthSamples, key: "ampify.healthSamples")
    }

    private func seedOrLoadHistoricalLedgers(current: BatteryReading) {
        let cal = Calendar.current
        let now = Date()

        if let savedHistory: [HistoryPoint] = Self.loadCodable(key: "ampify.recentHistory"), !savedHistory.isEmpty {
            recentHistory = savedHistory
        } else {
            var seeded: [HistoryPoint] = []
            for step in stride(from: 180, through: 0, by: -10) {
                let ts = now.addingTimeInterval(Double(-step * 60))
                let delta = Int((sin(Double(step) / 35.0) * 2.0).rounded())
                let pct = min(100, max(15, current.percentage + delta))
                seeded.append(
                    HistoryPoint(
                        timestamp: ts,
                        percentage: pct,
                        isPluggedIn: current.isPluggedIn,
                        isCharging: current.isCharging,
                        watts: current.batteryWatts,
                        temperatureC: current.temperatureCelsius
                    )
                )
            }
            recentHistory = seeded
        }

        if let savedBuckets: [DailyHighChargeBucket] = Self.loadCodable(key: "ampify.dailyHighChargeBuckets"), !savedBuckets.isEmpty {
            dailyHighChargeBuckets = savedBuckets
        } else {
            var seededBuckets: [DailyHighChargeBucket] = []
            let samplePluggedMins = [25, 40, 15, 0, 35, 20, current.percentage > 80 ? 30 : 10]
            let sampleUnpluggedMins = [10, 15, 5, 0, 10, 5, 0]
            for offset in (0..<7).reversed() {
                let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now)) ?? now
                let idx = 6 - offset
                seededBuckets.append(
                    DailyHighChargeBucket(
                        dateKey: Self.dateKey(for: day),
                        date: day,
                        pluggedMinutesAbove80: samplePluggedMins[idx],
                        unpluggedMinutesAbove80: sampleUnpluggedMins[idx],
                        totalPluggedMinutes: 240,
                        peakTemperatureC: current.temperatureCelsius
                    )
                )
            }
            dailyHighChargeBuckets = seededBuckets
        }
        weekSummary = WeekSummary.compute(from: dailyHighChargeBuckets)

        if let savedHealth: [HealthSample] = Self.loadCodable(key: "ampify.healthSamples"), savedHealth.count >= 4 {
            healthSamples = savedHealth
        } else {
            var seededHealth: [HealthSample] = []
            for monthsBack in stride(from: 6, through: 0, by: -1) {
                let date = cal.date(byAdding: .month, value: -monthsBack, to: cal.startOfDay(for: now)) ?? now
                let extraHealth = min(100, current.healthPercent + (monthsBack / 2))
                let extraCap = min(current.designCapacitymAh, current.nominalCapacitymAh + monthsBack * 12)
                let earlierCycles = max(1, current.cycleCount - monthsBack * 6)
                seededHealth.append(
                    HealthSample(
                        dateKey: Self.dateKey(for: date),
                        date: date,
                        healthPercent: extraHealth,
                        nominalCapacitymAh: extraCap,
                        designCapacitymAh: current.designCapacitymAh,
                        cycleCount: earlierCycles
                    )
                )
            }
            healthSamples = seededHealth
        }
        healthProjection = HealthProjection.analyze(samples: healthSamples, currentReading: current)

        if let savedDepartures: [DeparturePrediction] = Self.loadCodable(key: "ampify.departurePredictions"), !savedDepartures.isEmpty {
            departurePredictions = savedDepartures
        } else {
            departurePredictions = [
                DeparturePrediction(weekday: 2, typicalMinuteOfDay: 8 * 60 + 45, confidence: 0.86, sampleCount: 6),
                DeparturePrediction(weekday: 3, typicalMinuteOfDay: 8 * 60 + 50, confidence: 0.84, sampleCount: 5),
                DeparturePrediction(weekday: 4, typicalMinuteOfDay: 8 * 60 + 45, confidence: 0.88, sampleCount: 7),
                DeparturePrediction(weekday: 5, typicalMinuteOfDay: 9 * 60 + 0, confidence: 0.80, sampleCount: 5),
                DeparturePrediction(weekday: 6, typicalMinuteOfDay: 9 * 60 + 15, confidence: 0.78, sampleCount: 4)
            ]
        }

        if let savedStretches: [BatteryStretch] = Self.loadCodable(key: "ampify.batteryStretches"), !savedStretches.isEmpty {
            batteryStretches = savedStretches
        } else {
            batteryStretches = [
                BatteryStretch(
                    startDate: now.addingTimeInterval(-26 * 3600),
                    endDate: now.addingTimeInterval(-23.5 * 3600),
                    fromPercent: 80,
                    toPercent: 58,
                    awakeMinutes: 150
                ),
                BatteryStretch(
                    startDate: now.addingTimeInterval(-50 * 3600),
                    endDate: now.addingTimeInterval(-47 * 3600),
                    fromPercent: 80,
                    toPercent: 54,
                    awakeMinutes: 180
                )
            ]
        }

        if let savedSleep: [SleepDrainEpisode] = Self.loadCodable(key: "ampify.sleepEpisodes"), !savedSleep.isEmpty {
            sleepEpisodes = savedSleep
        } else {
            let lastNightWake = cal.date(bySettingHour: 8, minute: 15, second: 0, of: now) ?? now
            let lastNightSleep = lastNightWake.addingTimeInterval(-7.5 * 3600)
            sleepEpisodes = [
                SleepDrainEpisode(
                    sleptAt: lastNightSleep,
                    wokeAt: lastNightWake,
                    startPercent: min(100, current.percentage + 2),
                    endPercent: current.percentage,
                    darkWakeCount: 1
                )
            ]
        }
    }

    private func recordUnplugDepartureEvent() {
        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        if let idx = departurePredictions.firstIndex(where: { $0.weekday == weekday }) {
            var pred = departurePredictions[idx]
            pred.typicalMinuteOfDay = Int((Double(pred.typicalMinuteOfDay * pred.sampleCount + mins) / Double(pred.sampleCount + 1)).rounded())
            pred.sampleCount += 1
            pred.confidence = min(0.98, pred.confidence + 0.02)
            departurePredictions[idx] = pred
        } else {
            departurePredictions.append(
                DeparturePrediction(weekday: weekday, typicalMinuteOfDay: mins, confidence: 0.65, sampleCount: 1)
            )
        }
        saveCodable(departurePredictions, key: "ampify.departurePredictions")
    }

    private func setupWorkspaceSleepObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.sleepStartedAt = Date()
                self.sleepStartPercent = self.reading.percentage
            }
        }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                let current = self.batterySource.readCurrent()
                if let sleptAt = self.sleepStartedAt,
                   let startPct = self.sleepStartPercent,
                   now.timeIntervalSince(sleptAt) >= 1800 {
                    let episode = SleepDrainEpisode(
                        sleptAt: sleptAt,
                        wokeAt: now,
                        startPercent: startPct,
                        endPercent: current.percentage,
                        darkWakeCount: 0
                    )
                    self.sleepEpisodes.insert(episode, at: 0)
                    self.sleepEpisodes = Array(self.sleepEpisodes.prefix(10))
                    self.saveCodable(self.sleepEpisodes, key: "ampify.sleepEpisodes")
                }
                self.sleepStartedAt = nil
                self.sleepStartPercent = nil
                self.refreshLiveState()
            }
        }
    }

    // MARK: - Quiet Alerts

    private func evaluateAlerts(for current: BatteryReading) {
        if alertThresholds.notifyOnWarmBattery && current.temperatureCelsius >= alertThresholds.warmThresholdCelsius {
            recordAlertOncePerHour(
                title: "Battery is warm (\(String(format: "%.1f °C", current.temperatureCelsius)))",
                message: "High heat combined with charging speeds up battery aging. Improve airflow or pause heavy workloads."
            )
        }
        if alertThresholds.notifyWhenLimitReached,
           let limit = current.activeChargeLimit,
           current.isPluggedIn,
           !current.isCharging,
           abs(current.percentage - limit) <= 1 {
            recordAlertOncePerHour(
                title: "Holding at \(limit)% charge limit",
                message: "Your Mac is now running directly from the power adapter."
            )
        }
        if alertThresholds.notifyOnLowDeviceBattery {
            for dev in appleDevices where dev.batteryPercent <= alertThresholds.lowDevicePercentThreshold && !dev.isCharging {
                recordAlertOncePerHour(
                    title: "\(dev.name) battery is low (\(dev.batteryPercent)%)",
                    message: "Discovered over Wi-Fi (\(dev.marketingModel))."
                )
            }
        }
    }

    private func recordAlertOncePerHour(title: String, message: String) {
        let now = Date()
        if let recent = alertLog.first(where: { $0.title == title }),
           now.timeIntervalSince(recent.timestamp) < 3600 {
            return
        }
        let entry = AlertLogEntry(timestamp: now, title: title, message: message)
        alertLog.insert(entry, at: 0)
        alertLog = Array(alertLog.prefix(20))

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            let req = UNNotificationRequest(identifier: entry.id.uuidString, content: content, trigger: nil)
            center.add(req)
        }
    }

    private static func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func saveCodable<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadCodable<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// Inline Widget Preview View for Shareable Card & Widgets Tab
public struct SnapshotEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetSnapshot
    public init(date: Date = Date(), snapshot: WidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct BatteryWidgetView: View {
    public let entry: SnapshotEntry
    public var isSmall: Bool = false

    public init(entry: SnapshotEntry, isSmall: Bool = false) {
        self.entry = entry
        self.isSmall = isSmall
    }

    public var body: some View {
        if isSmall {
            smallCard
        } else {
            mediumCard
        }
    }

    private var smallCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                BatteryGlyphView(
                    percentage: entry.snapshot.percentage,
                    limit: entry.snapshot.activeLimit,
                    isCharging: entry.snapshot.isCharging,
                    isPluggedIn: entry.snapshot.isPluggedIn,
                    width: 34,
                    height: 15
                )
                Spacer()
                Text(entry.snapshot.badgeText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(entry.snapshot.percentage)%")
                .font(.system(size: 24, weight: .medium))
                .monospacedDigit()
            Text(entry.snapshot.healthLine)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let devName = entry.snapshot.primaryDeviceName,
               let devPct = entry.snapshot.primaryDevicePercent {
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(devName)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(devPct)%")
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                }
            } else {
                Text(entry.snapshot.highChargeLine)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 164, height: 164, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AmpifyTheme.surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
        )
    }

    private var mediumCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    BatteryGlyphView(
                        percentage: entry.snapshot.percentage,
                        limit: entry.snapshot.activeLimit,
                        isCharging: entry.snapshot.isCharging,
                        isPluggedIn: entry.snapshot.isPluggedIn,
                        width: 38,
                        height: 16
                    )
                    Text("\(entry.snapshot.percentage)%")
                        .font(.system(size: 24, weight: .medium))
                        .monospacedDigit()
                }
                Text(entry.snapshot.badgeText)
                    .font(.system(size: 11.5, weight: .medium))
                Text(entry.snapshot.headline)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                row(icon: "heart", title: "Health", value: "\(entry.snapshot.healthPercent)% · \(entry.snapshot.cycleCount)c")
                row(icon: "chart.bar", title: "Above 80%", value: String(format: "%.1fh / wk", entry.snapshot.hoursAbove80ThisWeek))
                if let devName = entry.snapshot.primaryDeviceName,
                   let devPct = entry.snapshot.primaryDevicePercent {
                    row(icon: "iphone", title: devName, value: "\(devPct)%")
                }
                if let wName = entry.snapshot.watchName,
                   let wPct = entry.snapshot.watchPercent {
                    row(icon: "applewatch", title: wName, value: "\(wPct)%")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 344, height: 164, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AmpifyTheme.surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
        )
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }
}
