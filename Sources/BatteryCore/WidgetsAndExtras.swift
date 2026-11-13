import Foundation
import SwiftUI
import AppKit
import WidgetKit
#if canImport(AmpifyBridge)
import AmpifyBridge
#endif

public enum AmpifyResourceBundle {
    public static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let mainURL = Bundle.main.url(forResource: name, withExtension: ext) {
            return mainURL
        }
        #if SWIFT_PACKAGE
        if let modURL = Bundle.module.url(forResource: name, withExtension: ext) {
            return modURL
        }
        #endif
        return nil
    }
}

// MARK: - Ecosystem Device Slots & App Power Items for Widgets & UI

public struct EcosystemDeviceSlot: Identifiable, Codable, Equatable, Sendable {
    public enum Category: String, CaseIterable, Codable, Sendable {
        case iPhone
        case iPad
        case appleWatch
        case airPods
        case applePencil
        case appleTV
        case mac
        case keyboard
        case mouse
        case trackpad

        public var defaultTitle: String {
            switch self {
            case .iPhone: return "iPhone"
            case .iPad: return "iPad"
            case .appleWatch: return "Watch"
            case .airPods: return "AirPods"
            case .applePencil: return "Pencil"
            case .appleTV: return "Apple TV"
            case .mac: return "This Mac"
            case .keyboard: return "Keyboard"
            case .mouse: return "Mouse"
            case .trackpad: return "Trackpad"
            }
        }

        public var sfSymbol: String {
            switch self {
            case .iPhone: return "iphone"
            case .iPad: return "ipad"
            case .appleWatch: return "applewatch"
            case .airPods: return "airpodspro"
            case .applePencil: return "applepencil.gen2"
            case .appleTV: return "appletvremote.gen4"
            case .mac: return "laptopcomputer"
            case .keyboard: return "keyboard"
            case .mouse: return "magicmouse"
            case .trackpad: return "rectangle.and.hand.point.up.left"
            }
        }
    }

    public var id: String
    public var name: String
    public var shortLabel: String
    public var category: Category
    public var percent: Int
    public var isCharging: Bool
    public var isLiveConnected: Bool
    public var detailText: String

    public init(
        id: String,
        name: String,
        shortLabel: String? = nil,
        category: Category,
        percent: Int,
        isCharging: Bool = false,
        isLiveConnected: Bool = true,
        detailText: String = ""
    ) {
        self.id = id
        self.name = name
        self.shortLabel = shortLabel ?? category.defaultTitle
        self.category = category
        self.percent = min(100, max(0, percent))
        self.isCharging = isCharging
        self.isLiveConnected = isLiveConnected
        self.detailText = detailText
    }

    public static var defaultFourStrip: [EcosystemDeviceSlot] {
        [
            EcosystemDeviceSlot(id: "slot-iphone", name: "iPhone 15 Plus", shortLabel: "iPhone", category: .iPhone, percent: 60, isCharging: false, isLiveConnected: true, detailText: "Wi-Fi"),
            EcosystemDeviceSlot(id: "slot-ipad", name: "iPad Pro", shortLabel: "iPad", category: .iPad, percent: 57, isCharging: true, isLiveConnected: true, detailText: "Charging"),
            EcosystemDeviceSlot(id: "slot-watch", name: "Apple Watch", shortLabel: "Watch", category: .appleWatch, percent: 89, isCharging: false, isLiveConnected: true, detailText: "Paired"),
            EcosystemDeviceSlot(id: "slot-airpods", name: "AirPods Pro", shortLabel: "AirPods", category: .airPods, percent: 93, isCharging: false, isLiveConnected: true, detailText: "Case 96%")
        ]
    }

    public static var defaultExtendedEcosystem: [EcosystemDeviceSlot] {
        defaultFourStrip + [
            EcosystemDeviceSlot(id: "slot-pencil", name: "Apple Pencil Pro", shortLabel: "Pencil", category: .applePencil, percent: 100, isCharging: true, isLiveConnected: true, detailText: "Magnetic Dock"),
            EcosystemDeviceSlot(id: "slot-atv", name: "Apple TV Siri Remote", shortLabel: "Apple TV", category: .appleTV, percent: 84, isCharging: false, isLiveConnected: true, detailText: "Living Room"),
            EcosystemDeviceSlot(id: "slot-mac", name: "This MacBook", shortLabel: "MacBook", category: .mac, percent: 80, isCharging: false, isLiveConnected: true, detailText: "80% Hold"),
            EcosystemDeviceSlot(id: "slot-mouse", name: "Magic Mouse / Lift", shortLabel: "Mouse", category: .mouse, percent: 95, isCharging: false, isLiveConnected: true, detailText: "Bluetooth")
        ]
    }
}

public struct WidgetAppPowerItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String { name }
    public var name: String
    public var stateLabel: String?
    public var watts: Double
    public var isMacOSRow: Bool
    public var isEverythingElseRow: Bool

    public init(
        name: String,
        stateLabel: String? = "Idle",
        watts: Double,
        isMacOSRow: Bool = false,
        isEverythingElseRow: Bool = false
    ) {
        self.name = name
        self.stateLabel = stateLabel
        self.watts = watts
        self.isMacOSRow = isMacOSRow
        self.isEverythingElseRow = isEverythingElseRow
    }

    public static var defaultItems: [WidgetAppPowerItem] {
        [
            WidgetAppPowerItem(name: "Brave Browser", stateLabel: "Idle", watts: 0.2),
            WidgetAppPowerItem(name: "Terminal", stateLabel: "Idle", watts: 0.1),
            WidgetAppPowerItem(name: "macOS itself", stateLabel: "Idle", watts: 0.1, isMacOSRow: true),
            WidgetAppPowerItem(name: "Everything else", stateLabel: nil, watts: 0.1, isEverythingElseRow: true)
        ]
    }
}

// MARK: - WidgetSnapshot & WidgetBridge (Shared between Ampify and AmpifyWidget)

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var percentage: Int
    public var activeLimit: Int?
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var badgeText: String
    public var headline: String
    public var healthPercent: Int
    public var cycleCount: Int
    public var healthLine: String
    public var healthSubtitle: String
    public var hoursAbove80ThisWeek: Double
    public var highChargeLine: String
    public var powerWatts: Double
    public var primaryDeviceName: String?
    public var primaryDevicePercent: Int?
    public var watchName: String?
    public var watchPercent: Int?
    public var deviceSlots: [EcosystemDeviceSlot]
    public var appPowerItems: [WidgetAppPowerItem]
    public var totalAppWatts: Double
    public var appPowerSubtitle: String

    public init(
        timestamp: Date = Date(),
        percentage: Int = 80,
        activeLimit: Int? = 80,
        isPluggedIn: Bool = true,
        isCharging: Bool = false,
        badgeText: String = "Holding at 80%",
        headline: String = "Holding at 80% — running from the power adapter.",
        healthPercent: Int = 99,
        cycleCount: Int = 74,
        healthLine: String = "99% health · 74 cycles",
        healthSubtitle: String = "Normal wear, nothing to do.",
        hoursAbove80ThisWeek: Double = 1.4,
        highChargeLine: String = "1.4 hrs above 80% this week",
        powerWatts: Double = 0.0,
        primaryDeviceName: String? = nil,
        primaryDevicePercent: Int? = nil,
        watchName: String? = nil,
        watchPercent: Int? = nil,
        deviceSlots: [EcosystemDeviceSlot] = EcosystemDeviceSlot.defaultExtendedEcosystem,
        appPowerItems: [WidgetAppPowerItem] = WidgetAppPowerItem.defaultItems,
        totalAppWatts: Double = 0.4,
        appPowerSubtitle: String = "Nothing is working hard right now."
    ) {
        self.timestamp = timestamp
        self.percentage = percentage
        self.activeLimit = activeLimit
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.badgeText = badgeText
        self.headline = headline
        self.healthPercent = healthPercent
        self.cycleCount = cycleCount
        self.healthLine = healthLine
        self.healthSubtitle = healthSubtitle
        self.hoursAbove80ThisWeek = hoursAbove80ThisWeek
        self.highChargeLine = highChargeLine
        self.powerWatts = powerWatts
        self.primaryDeviceName = primaryDeviceName
        self.primaryDevicePercent = primaryDevicePercent
        self.watchName = watchName
        self.watchPercent = watchPercent
        self.deviceSlots = deviceSlots
        self.appPowerItems = appPowerItems
        self.totalAppWatts = totalAppWatts
        self.appPowerSubtitle = appPowerSubtitle
    }
}

public enum WidgetBridge {
    public static let appGroupIdentifier = "9TKKPN6F59.me.cogify.ampify"

    public static var appGroupContainerURL: URL? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        let fallbackGroup = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Group Containers/\(appGroupIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallbackGroup, withIntermediateDirectories: true)
        return fallbackGroup
    }

    public static var sharedDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("Ampify", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var appGroupSnapshotURL: URL? {
        appGroupContainerURL?.appendingPathComponent("snapshot.json")
    }

    public static var snapshotFileURL: URL {
        sharedDirectoryURL.appendingPathComponent("snapshot.json")
    }

    public static var sharedTempSnapshotURL: URL {
        URL(fileURLWithPath: "/tmp/ampify-widget-snapshot.json")
    }

    public static func write(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        if let groupURL = appGroupSnapshotURL {
            try? data.write(to: groupURL, options: .atomic)
        }
        try? data.write(to: snapshotFileURL, options: .atomic)
        try? data.write(to: sharedTempSnapshotURL, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func readLatest() -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var candidateURLs: [URL] = []
        if let groupURL = appGroupSnapshotURL {
            candidateURLs.append(groupURL)
        }
        candidateURLs.append(snapshotFileURL)
        candidateURLs.append(sharedTempSnapshotURL)
        for url in candidateURLs {
            if let data = try? Data(contentsOf: url),
               let snap = try? decoder.decode(WidgetSnapshot.self, from: data) {
                return snap
            }
        }
        // Fallback to live IOKit reading if snapshot.json hasn't been written yet
        let live = IOKitBatterySource.shared.readCurrent()
        return WidgetSnapshot(
            timestamp: Date(),
            percentage: live.percentage,
            activeLimit: live.activeChargeLimit,
            isPluggedIn: live.isPluggedIn,
            isCharging: live.isCharging,
            badgeText: live.activeChargeLimit.map { "Holding at \($0)%" } ?? (live.isPluggedIn ? "Plugged In" : "On Battery"),
            headline: live.isPluggedIn ? "Connected to power adapter" : "Running on battery power",
            healthPercent: live.healthPercent,
            cycleCount: live.cycleCount,
            healthLine: "\(live.healthPercent)% health · \(live.cycleCount) cycles",
            hoursAbove80ThisWeek: 1.2,
            highChargeLine: "1.2 hrs above 80% this week",
            powerWatts: live.batteryWatts
        )
    }
}

// MARK: - Power Flow & Charger Memory (PowerFlowView + ChargerReport)

public struct PowerFlowSnapshot: Equatable, Sendable {
    public enum ChargerVerdict: String, Sendable {
        case plenty = "Plenty of power"
        case enough = "Enough for current load"
        case slow = "Smaller than your usual charger"
        case weak = "Underpowered — battery may assist"
        case unplugged = "Running on battery"
    }

    public var isPluggedIn: Bool
    public var adapterRatedWatts: Int?
    public var fromChargerWatts: Double
    public var macUsesWatts: Double
    public var batteryWatts: Double
    public var isChargingBattery: Bool
    public var biggestSeenChargerWatts: Int
    public var verdict: ChargerVerdict
    public var summaryText: String

    public static func compute(from reading: BatteryReading, biggestSeenWatts: Int) -> PowerFlowSnapshot {
        if !reading.isPluggedIn {
            let draw = max(2.5, reading.systemLoadWatts ?? reading.batteryWatts)
            return PowerFlowSnapshot(
                isPluggedIn: false,
                adapterRatedWatts: nil,
                fromChargerWatts: 0,
                macUsesWatts: draw,
                batteryWatts: reading.batteryWatts,
                isChargingBattery: false,
                biggestSeenChargerWatts: biggestSeenWatts,
                verdict: .unplugged,
                summaryText: String(format: "Battery is supplying %.1f W to your Mac.", draw)
            )
        }

        let rated = reading.adapterWatts ?? 67
        let battW = reading.isCharging ? reading.batteryWatts : 0.0
        let macW = max(3.5, reading.systemLoadWatts ?? max(6.0, (reading.systemPowerInWatts ?? 14.0) - battW))
        let inW = reading.systemPowerInWatts ?? (macW + battW)

        let verdict: ChargerVerdict
        let summary: String
        if inW + 1.0 < macW && !reading.isCharging {
            verdict = .weak
            summary = "Your Mac is drawing more power than this \(rated)W adapter supplies."
        } else if biggestSeenWatts >= rated + 25 && rated <= 35 {
            verdict = .slow
            summary = "Connected to a \(rated)W charger (smaller than your usual \(biggestSeenWatts)W adapter)."
        } else if rated >= 60 {
            verdict = .plenty
            summary = reading.isCharging
                ? String(format: "%dW adapter powers your Mac (%.1f W) and charges the battery (+%.1f W).", rated, macW, battW)
                : String(format: "%dW adapter powers your Mac directly (%.1f W) while the battery rests.", rated, macW)
        } else {
            verdict = .enough
            summary = String(format: "%dW adapter is powering your Mac (%.1f W).", rated, macW)
        }

        return PowerFlowSnapshot(
            isPluggedIn: true,
            adapterRatedWatts: rated,
            fromChargerWatts: inW,
            macUsesWatts: macW,
            batteryWatts: battW,
            isChargingBattery: reading.isCharging,
            biggestSeenChargerWatts: max(biggestSeenWatts, rated),
            verdict: verdict,
            summaryText: summary
        )
    }
}

// MARK: - Battery Stretches & Usual Drain (Unplugged Runtime Pace)

public struct BatteryStretch: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date
    public var fromPercent: Int
    public var toPercent: Int
    public var awakeMinutes: Int

    public var lostPercent: Int {
        max(1, fromPercent - toPercent)
    }

    public var percentPerHour: Double {
        let hrs = max(0.25, Double(awakeMinutes) / 60.0)
        return Double(lostPercent) / hrs
    }

    public var estimatedFullRuntimeHours: Double {
        guard percentPerHour > 1.0 else { return 14.0 }
        return min(22.0, max(2.5, 100.0 / percentPerHour))
    }

    public var summaryLine: String {
        let hrs = Double(awakeMinutes) / 60.0
        return String(
            format: "%d%% → %d%% (−%d%% over %.1fh active · ~%.1f%%/hr)",
            fromPercent, toPercent, lostPercent, hrs, percentPerHour
        )
    }

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        fromPercent: Int,
        toPercent: Int,
        awakeMinutes: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.fromPercent = fromPercent
        self.toPercent = toPercent
        self.awakeMinutes = awakeMinutes
    }
}

// MARK: - Contextual Insights (NowInsightCard)

public struct BatteryInsight: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case chargerSlower
        case drainFast
        case nightDrain
        case smartOffer
        case devicesTip
    }

    public var id: String { kind.rawValue }
    public var kind: Kind
    public var symbol: String
    public var title: String
    public var detail: String
    public var actionLabel: String?
    public var targetSection: String?

    public init(
        kind: Kind,
        symbol: String,
        title: String,
        detail: String,
        actionLabel: String? = nil,
        targetSection: String? = nil
    ) {
        self.kind = kind
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.actionLabel = actionLabel
        self.targetSection = targetSection
    }
}

// MARK: - Diagnostics Report

public enum DiagnosticReportBuilder {
    public static func build(
        reading: BatteryReading,
        limitStatus: LimitWatchdog.Status,
        powerFlow: PowerFlowSnapshot,
        appleDevices: [ConnectedAppleDevice],
        accessories: [BluetoothAccessoryBattery]
    ) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let model = IOKitBatterySource.currentHardwareModelIdentifier()
        let bridgeDebug = ChargeLimitBridge.debugInfo()
        var lines: [String] = [
            "Ampify Diagnostics Report",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "----------------------------------------",
            "Hardware Model: \(model)",
            "macOS Version: \(os)",
            "PowerUI Supported: \(reading.isLimitSupported)",
            "Active Charge Limit: \(reading.activeChargeLimit.map { "\($0)%" } ?? "Off")",
            "Stored Charge Limit: \(reading.storedChargeLimit)%",
            "PowerUI Debug: \(bridgeDebug)",
            "Watchdog State: \(String(describing: limitStatus))",
            "----------------------------------------",
            "Battery Percentage: \(reading.percentage)%",
            "Plugged In: \(reading.isPluggedIn) · Charging: \(reading.isCharging) · Full: \(reading.isFullyCharged)",
            "Health: \(reading.healthPercent)% (\(reading.nominalCapacitymAh) / \(reading.designCapacitymAh) mAh, raw \(reading.rawMaxCapacitymAh) mAh)",
            "Cycles: \(reading.cycleCount) / \(reading.designCycleCount)",
            String(format: "Electrical: %.2f V · %+.2f A · %.1f W · %.1f °C (%@)",
                   reading.voltageVolts, reading.amperageAmps, reading.batteryWatts, reading.temperatureCelsius, reading.thermalBand.label),
            "Adapter: \(reading.adapterWatts.map { "\($0)W" } ?? "None") · Flow Verdict: \(powerFlow.verdict.rawValue)",
            "----------------------------------------",
            "Paired iOS / watchOS Devices (\(appleDevices.count)):"
        ]
        for dev in appleDevices {
            lines.append(" - \(dev.name) (\(dev.marketingModel), \(dev.productType)): \(dev.batteryPercent)% · charging=\(dev.isCharging) · health=\(dev.healthPercent.map { "\($0)%" } ?? "n/a") · cycles=\(dev.cycleCount.map(String.init) ?? "n/a")")
        }
        lines.append("Bluetooth Accessories (\(accessories.count)):")
        for acc in accessories {
            lines.append(" - \(acc.name) (\(acc.kind.rawValue)): \(acc.detailSummary)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Shared Liquid-Wave Apple Device Silhouettes & "What's Using Power" Components

public struct LiquidWaveShape: Shape {
    public var progress: Double
    public var waveHeight: CGFloat
    public var phaseOffset: Double

    public init(progress: Double, waveHeight: CGFloat = 2.6, phaseOffset: Double = 0.0) {
        self.progress = min(1.0, max(0.0, progress))
        self.waveHeight = waveHeight
        self.phaseOffset = phaseOffset
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 && progress > 0.01 else { return path }
        let clamped = min(0.98, max(0.06, progress))
        let baseY = rect.height * CGFloat(1.0 - clamped)

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: baseY))

        let steps = max(16, Int(rect.width))
        for step in 0...steps {
            let x = CGFloat(step) / CGFloat(steps) * rect.width
            let normalized = Double(x / rect.width)
            let angle = normalized * .pi * 2.0 + phaseOffset
            let y = baseY + sin(angle) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

public struct LiquidChamberFillView: View {
    public let percent: Int
    public let isCharging: Bool
    public let phaseOffset: Double
    public var showBoltSize: CGFloat = 14

    public init(percent: Int, isCharging: Bool, phaseOffset: Double = 0.4, showBoltSize: CGFloat = 14) {
        self.percent = percent
        self.isCharging = isCharging
        self.phaseOffset = phaseOffset
        self.showBoltSize = showBoltSize
    }

    private var topColor: Color {
        if percent <= 15 && !isCharging {
            return Color(red: 0.98, green: 0.46, blue: 0.42)
        }
        if percent <= 25 && !isCharging {
            return Color(red: 0.98, green: 0.72, blue: 0.36)
        }
        return Color(red: 0.65, green: 0.94, blue: 0.78)
    }

    private var bottomColor: Color {
        if percent <= 15 && !isCharging {
            return Color(red: 0.85, green: 0.28, blue: 0.26)
        }
        if percent <= 25 && !isCharging {
            return Color(red: 0.88, green: 0.54, blue: 0.20)
        }
        return Color(red: 0.38, green: 0.79, blue: 0.59)
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.11, green: 0.12, blue: 0.15)

                // Back subtle wave
                LiquidWaveShape(
                    progress: Double(percent) / 100.0,
                    waveHeight: max(1.6, geo.size.height * 0.042),
                    phaseOffset: phaseOffset + 1.9
                )
                .fill(topColor.opacity(0.42))

                // Primary liquid wave fill
                LiquidWaveShape(
                    progress: Double(percent) / 100.0,
                    waveHeight: max(1.8, geo.size.height * 0.048),
                    phaseOffset: phaseOffset
                )
                .fill(
                    LinearGradient(
                        colors: [topColor, bottomColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Rising charging bubbles & lightning bolt
                if isCharging {
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 4.2, height: 4.2)
                        .offset(x: -geo.size.width * 0.24, y: geo.size.height * 0.10)
                    Circle()
                        .fill(Color.white.opacity(0.38))
                        .frame(width: 2.8, height: 2.8)
                        .offset(x: geo.size.width * 0.22, y: geo.size.height * 0.24)
                    Circle()
                        .fill(Color.white.opacity(0.30))
                        .frame(width: 2.4, height: 2.4)
                        .offset(x: -geo.size.width * 0.14, y: -geo.size.height * 0.18)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: showBoltSize, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.28), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
}

public struct LiquidDeviceSilhouetteView: View {
    public let slot: EcosystemDeviceSlot
    public var showLabel: Bool = false
    public var compact: Bool = false

    public init(slot: EcosystemDeviceSlot, showLabel: Bool = false, compact: Bool = false) {
        self.slot = slot
        self.showLabel = showLabel
        self.compact = compact
    }

    private var glowColor: Color {
        if slot.percent <= 20 && !slot.isCharging {
            return Color(red: 0.95, green: 0.62, blue: 0.30)
        }
        return Color(red: 0.54, green: 0.89, blue: 0.72)
    }

    public var body: some View {
        let scale: CGFloat = compact ? 0.80 : 1.0
        VStack(spacing: compact ? 5 : 7) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowColor.opacity(0.20), glowColor.opacity(0.04), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 34 * scale
                        )
                    )
                    .frame(width: 64 * scale, height: 64 * scale)

                silhouetteGraphic(scale: scale)
            }
            .frame(height: 58 * scale)

            VStack(spacing: 1) {
                Text("\(slot.percent)%")
                    .font(.system(size: compact ? 12 : 13.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                if showLabel {
                    Text(slot.shortLabel)
                        .font(.system(size: compact ? 9.5 : 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func silhouetteGraphic(scale: CGFloat) -> some View {
        switch slot.category {
        case .iPhone:
            iPhoneSilhouette(scale: scale)
        case .iPad:
            iPadSilhouette(scale: scale)
        case .appleWatch:
            watchSilhouette(scale: scale)
        case .airPods:
            airPodsSilhouette(scale: scale)
        case .applePencil:
            pencilSilhouette(scale: scale)
        case .appleTV:
            appleTVRemoteSilhouette(scale: scale)
        case .mac:
            macBookSilhouette(scale: scale)
        case .keyboard, .trackpad:
            keyboardSilhouette(scale: scale)
        case .mouse:
            mouseSilhouette(scale: scale)
        }
    }

    private func iPhoneSilhouette(scale: CGFloat) -> some View {
        let w = 27 * scale
        let h = 54 * scale
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6.5 * scale, style: .continuous)
                .fill(Color(red: 0.18, green: 0.19, blue: 0.23))
                .frame(width: w, height: h)

            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: 0.3,
                showBoltSize: 12 * scale
            )
            .frame(width: w - 3.2 * scale, height: h - 3.2 * scale)
            .clipShape(RoundedRectangle(cornerRadius: 5.2 * scale, style: .continuous))
            .padding(.top, 1.6 * scale)

            // Dynamic Island
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(width: 8.5 * scale, height: 2.4 * scale)
                .padding(.top, 3.8 * scale)

            RoundedRectangle(cornerRadius: 6.5 * scale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.1)
                .frame(width: w, height: h)
        }
    }

    private func iPadSilhouette(scale: CGFloat) -> some View {
        let w = 39 * scale
        let h = 53 * scale
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5.5 * scale, style: .continuous)
                .fill(Color(red: 0.16, green: 0.17, blue: 0.21))
                .frame(width: w, height: h)

            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: 1.1,
                showBoltSize: 15 * scale
            )
            .frame(width: w - 4.4 * scale, height: h - 4.4 * scale)
            .clipShape(RoundedRectangle(cornerRadius: 3.8 * scale, style: .continuous))
            .padding(.top, 2.2 * scale)

            RoundedRectangle(cornerRadius: 5.5 * scale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1.1)
                .frame(width: w, height: h)
        }
    }

    private func watchSilhouette(scale: CGFloat) -> some View {
        let caseW = 29 * scale
        let caseH = 34 * scale
        let bandW = 16 * scale
        return ZStack {
            // Top & bottom watch straps
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                    .fill(Color(red: 0.24, green: 0.25, blue: 0.30))
                    .frame(width: bandW, height: 11 * scale)
                Spacer(minLength: caseH - 6 * scale)
                RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                    .fill(Color(red: 0.24, green: 0.25, blue: 0.30))
                    .frame(width: bandW, height: 11 * scale)
            }
            .frame(height: 52 * scale)

            // Digital Crown
            RoundedRectangle(cornerRadius: 1.5 * scale, style: .continuous)
                .fill(Color.white.opacity(0.45))
                .frame(width: 2.5 * scale, height: 7.5 * scale)
                .offset(x: caseW * 0.52, y: -4 * scale)

            // Watch Case
            RoundedRectangle(cornerRadius: 8.5 * scale, style: .continuous)
                .fill(Color(red: 0.32, green: 0.33, blue: 0.38))
                .frame(width: caseW, height: caseH)

            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: 2.0,
                showBoltSize: 12 * scale
            )
            .frame(width: caseW - 3.6 * scale, height: caseH - 3.6 * scale)
            .clipShape(RoundedRectangle(cornerRadius: 6.8 * scale, style: .continuous))

            RoundedRectangle(cornerRadius: 8.5 * scale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.1)
                .frame(width: caseW, height: caseH)
        }
    }

    private func airPodsSilhouette(scale: CGFloat) -> some View {
        HStack(spacing: 4.5 * scale) {
            singleAirPodBud(isLeft: true, scale: scale)
            singleAirPodBud(isLeft: false, scale: scale)
        }
    }

    private func singleAirPodBud(isLeft: Bool, scale: CGFloat) -> some View {
        let w = 18 * scale
        let h = 40 * scale
        return ZStack(alignment: .top) {
            // Stem + Head composite shape masked over liquid fill
            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: isLeft ? 0.5 : 1.7,
                showBoltSize: 9 * scale
            )
            .frame(width: w, height: h)
            .mask(
                ZStack(alignment: .top) {
                    // Earbud head
                    Ellipse()
                        .frame(width: 17.5 * scale, height: 15.5 * scale)
                        .offset(x: isLeft ? -1 * scale : 1 * scale, y: 0)
                    // Stem
                    RoundedRectangle(cornerRadius: 3.2 * scale, style: .continuous)
                        .frame(width: 6.5 * scale, height: 27 * scale)
                        .offset(x: isLeft ? 3.2 * scale : -3.2 * scale, y: 11 * scale)
                }
            )

            // Acoustic dark vent & ear-tip ring
            Circle()
                .fill(Color(red: 0.14, green: 0.17, blue: 0.20).opacity(0.75))
                .frame(width: 6.8 * scale, height: 6.8 * scale)
                .offset(x: isLeft ? -2.8 * scale : 2.8 * scale, y: 4.4 * scale)
        }
        .frame(width: w, height: h)
    }

    private func pencilSilhouette(scale: CGFloat) -> some View {
        let w = 13 * scale
        let h = 54 * scale
        return ZStack(alignment: .top) {
            VStack(spacing: 1 * scale) {
                // Tapered tip
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 5 * scale, height: 6 * scale)
                // Main Pencil barrel with liquid wave
                ZStack {
                    RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.19, blue: 0.23))
                        .frame(width: w, height: h - 7 * scale)

                    LiquidChamberFillView(
                        percent: slot.percent,
                        isCharging: slot.isCharging,
                        phaseOffset: 0.9,
                        showBoltSize: 9.5 * scale
                    )
                    .frame(width: w - 2.6 * scale, height: h - 9.6 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 3 * scale, style: .continuous))

                    RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
                        .frame(width: w, height: h - 7 * scale)
                }
            }
        }
    }

    private func appleTVRemoteSilhouette(scale: CGFloat) -> some View {
        let w = 22 * scale
        let h = 53 * scale
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5.5 * scale, style: .continuous)
                .fill(Color(red: 0.20, green: 0.21, blue: 0.26))
                .frame(width: w, height: h)

            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: 1.4,
                showBoltSize: 11 * scale
            )
            .frame(width: w - 3 * scale, height: h - 3 * scale)
            .clipShape(RoundedRectangle(cornerRadius: 4.2 * scale, style: .continuous))
            .padding(.top, 1.5 * scale)

            // Clickpad ring at top of Siri Remote
            Circle()
                .strokeBorder(Color.black.opacity(0.45), lineWidth: 1.4 * scale)
                .frame(width: 13 * scale, height: 13 * scale)
                .padding(.top, 5 * scale)

            RoundedRectangle(cornerRadius: 5.5 * scale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.1)
                .frame(width: w, height: h)
        }
    }

    private func macBookSilhouette(scale: CGFloat) -> some View {
        let screenW = 42 * scale
        let screenH = 29 * scale
        return VStack(spacing: 1.5 * scale) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.8 * scale, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.17, blue: 0.21))
                    .frame(width: screenW, height: screenH)

                LiquidChamberFillView(
                    percent: slot.percent,
                    isCharging: slot.isCharging,
                    phaseOffset: 0.7,
                    showBoltSize: 11 * scale
                )
                .frame(width: screenW - 3.6 * scale, height: screenH - 3.6 * scale)
                .clipShape(RoundedRectangle(cornerRadius: 2.6 * scale, style: .continuous))

                RoundedRectangle(cornerRadius: 3.8 * scale, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                    .frame(width: screenW, height: screenH)
            }
            RoundedRectangle(cornerRadius: 2 * scale, style: .continuous)
                .fill(Color.white.opacity(0.32))
                .frame(width: 48 * scale, height: 3.5 * scale)
        }
    }

    private func keyboardSilhouette(scale: CGFloat) -> some View {
        let w = 42 * scale
        let h = 26 * scale
        return ZStack {
            RoundedRectangle(cornerRadius: 4.5 * scale, style: .continuous)
                .fill(Color(red: 0.18, green: 0.19, blue: 0.23))
                .frame(width: w, height: h)

            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: 1.2,
                showBoltSize: 10 * scale
            )
            .frame(width: w - 3.2 * scale, height: h - 3.2 * scale)
            .clipShape(RoundedRectangle(cornerRadius: 3.2 * scale, style: .continuous))

            RoundedRectangle(cornerRadius: 4.5 * scale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                .frame(width: w, height: h)
        }
    }

    private func mouseSilhouette(scale: CGFloat) -> some View {
        let w = 25 * scale
        let h = 44 * scale
        return ZStack(alignment: .top) {
            Capsule(style: .continuous)
                .fill(Color(red: 0.18, green: 0.19, blue: 0.23))
                .frame(width: w, height: h)

            LiquidChamberFillView(
                percent: slot.percent,
                isCharging: slot.isCharging,
                phaseOffset: 1.6,
                showBoltSize: 11 * scale
            )
            .frame(width: w - 3.2 * scale, height: h - 3.2 * scale)
            .clipShape(Capsule(style: .continuous))
            .padding(.top, 1.6 * scale)

            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1.1)
                .frame(width: w, height: h)
        }
    }
}

public struct AppleDevicesLiquidStripCard: View {
    public let slots: [EcosystemDeviceSlot]
    public var showLabels: Bool = false
    public var compact: Bool = false
    public var onSelectSlot: ((EcosystemDeviceSlot) -> Void)? = nil

    public init(
        slots: [EcosystemDeviceSlot],
        showLabels: Bool = false,
        compact: Bool = false,
        onSelectSlot: ((EcosystemDeviceSlot) -> Void)? = nil
    ) {
        self.slots = slots
        self.showLabels = showLabels
        self.compact = compact
        self.onSelectSlot = onSelectSlot
    }

    public var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            ForEach(slots.prefix(4)) { slot in
                if let onSelectSlot {
                    Button {
                        onSelectSlot(slot)
                    } label: {
                        LiquidDeviceSilhouetteView(slot: slot, showLabel: showLabels, compact: compact)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(slot.name): \(slot.percent)% (\(slot.detailText))")
                } else {
                    LiquidDeviceSilhouetteView(slot: slot, showLabel: showLabels, compact: compact)
                }
            }
        }
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, compact ? 10 : 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        )
    }
}

public struct BatteryHealthBannerCard: View {
    public let healthPercent: Int
    public let subtitle: String
    public var compact: Bool = false

    public init(healthPercent: Int, subtitle: String = "Normal wear, nothing to do.", compact: Bool = false) {
        self.healthPercent = healthPercent
        self.subtitle = subtitle
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
                Image(systemName: "heart.fill")
                    .font(.system(size: compact ? 14 : 16, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Battery health")
                    .font(.system(size: compact ? 12.5 : 13.5, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: compact ? 11 : 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(healthPercent)%")
                .font(.system(size: compact ? 20 : 25, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 10 : 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        )
    }
}

// MARK: - "What's Using Power" Shared Card (Matches Reference Image 2 in Cogify Helium Theme)

public struct WhatsUsingPowerSectionView: View {
    public let entries: [AppEnergyEntry]
    public var compact: Bool = false
    public var allowAppActions: Bool = true
    public var onQuitApp: ((pid_t) -> Void)? = nil

    public init(
        entries: [AppEnergyEntry],
        compact: Bool = false,
        allowAppActions: Bool = true,
        onQuitApp: ((pid_t) -> Void)? = nil
    ) {
        self.entries = entries
        self.compact = compact
        self.allowAppActions = allowAppActions
        self.onQuitApp = onQuitApp
    }

    private var displayEntries: [AppEnergyEntry] {
        if entries.isEmpty {
            return [
                AppEnergyEntry(pid: 101, bundleIdentifier: "com.apple.Safari", name: "Safari", watts: 0.2, cpuPercent: 1.4, extraMinutesIfQuit: nil, kind: .application),
                AppEnergyEntry(pid: 102, bundleIdentifier: "com.apple.Terminal", name: "Terminal", watts: 0.1, cpuPercent: 0.8, extraMinutesIfQuit: nil, kind: .application),
                AppEnergyEntry(pid: -1, bundleIdentifier: "com.apple.finder", name: "macOS itself", watts: 0.1, cpuPercent: 1.0, extraMinutesIfQuit: nil, kind: .macOSItself),
                AppEnergyEntry(pid: -2, bundleIdentifier: nil, name: "Everything else", watts: 0.1, cpuPercent: 0.5, extraMinutesIfQuit: nil, kind: .everythingElse)
            ]
        }
        return entries
    }

    private var totalWatts: Double {
        let sum = displayEntries.map(\.watts).reduce(0.0, +)
        return max(0.1, sum)
    }

    private var maxRowWatts: Double {
        max(0.2, displayEntries.map(\.watts).max() ?? 0.2)
    }

    private var statusSubtitle: String {
        if totalWatts >= 6.0 {
            return "Apps are working hard right now."
        }
        if totalWatts >= 2.2 {
            return "Moderate app activity right now."
        }
        return "Nothing is working hard right now."
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("What's using power")
                        .font(.system(size: compact ? 13.5 : 16, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(statusSubtitle)
                        .font(.system(size: compact ? 11 : 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f W", totalWatts))
                        .font(.system(size: compact ? 18 : 24, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("going to your apps right now")
                        .font(.system(size: compact ? 10 : 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                let rows = Array(displayEntries.prefix(compact ? 4 : 6))
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    powerRow(for: item)
                    if index < rows.count - 1 {
                        Divider()
                            .opacity(0.6)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            )
        }
    }

    private func powerRow(for item: AppEnergyEntry) -> some View {
        let ratio = min(1.0, max(0.10, item.watts / maxRowWatts))
        return HStack(alignment: .center, spacing: 12) {
            appIconView(for: item)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let state = item.stateLabel {
                        Text(state)
                            .font(.system(size: compact ? 10.5 : 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if allowAppActions && item.kind == .application && item.pid > 0 {
                        Menu {
                            Button("Bring \(item.name) to Front") {
                                NSRunningApplication(processIdentifier: item.pid)?.activate()
                            }
                            if let appURL = NSRunningApplication(processIdentifier: item.pid)?.bundleURL {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                                }
                            }
                            Divider()
                            Button("Quit \(item.name)") {
                                if let onQuitApp {
                                    onQuitApp(item.pid)
                                } else {
                                    NSRunningApplication(processIdentifier: item.pid)?.terminate()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 16)
                        .help("Actions for \(item.name)")
                    }

                    Text(String(format: "%.1f W", item.watts))
                        .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 5)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.65, green: 0.94, blue: 0.78),
                                        Color(red: 0.42, green: 0.83, blue: 0.63)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(14, geo.size.width * CGFloat(ratio)), height: 5)
                            .shadow(color: Color(red: 0.50, green: 0.89, blue: 0.70).opacity(0.35), radius: 3, x: 0, y: 0)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 8.5 : 10.5)
    }

    @ViewBuilder
    private func appIconView(for item: AppEnergyEntry) -> some View {
        let iconSize: CGFloat = compact ? 24 : 28
        switch item.kind {
        case .macOSItself:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: iconSize, height: iconSize)
                Image(systemName: "apple.logo")
                    .font(.system(size: iconSize * 0.48, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        case .everythingElse:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: iconSize, height: iconSize)
                Image(systemName: "ellipsis")
                    .font(.system(size: iconSize * 0.45, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        case .application:
            if let nsImg = resolveApplicationIcon(pid: item.pid, bundleId: item.bundleIdentifier, name: item.name) {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: iconSize, height: iconSize)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: "app.fill")
                        .font(.system(size: iconSize * 0.48, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func resolveApplicationIcon(pid: pid_t, bundleId: String?, name: String) -> NSImage? {
        if pid > 0, let running = NSRunningApplication(processIdentifier: pid), let icon = running.icon {
            return icon
        }
        if let bundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        if name.lowercased().contains("brave") || name.lowercased().contains("safari") {
            if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                return NSWorkspace.shared.icon(forFile: safariURL.path)
            }
        }
        let candidates = [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
            "/System/Cryptexes/App/System/Applications/\(name).app",
            "/System/Applications/Utilities/\(name).app"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}
