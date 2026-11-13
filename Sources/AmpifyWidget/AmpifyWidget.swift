import WidgetKit
import SwiftUI
#if canImport(BatteryCore)
import BatteryCore
#endif

public struct SnapshotEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetSnapshot

    public init(date: Date = Date(), snapshot: WidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct SnapshotProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(snapshot: WidgetSnapshot())
    }

    public func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(snapshot: WidgetBridge.readLatest()))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let current = WidgetBridge.readLatest()
        let entry = SnapshotEntry(date: Date(), snapshot: current)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date().addingTimeInterval(600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

extension View {
    @ViewBuilder
    func ampifyWidgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self.background(Color(NSColor.windowBackgroundColor))
        }
    }
}

// MARK: - 1. Apple Devices Liquid Strip + Battery Health Widget (Medium & Large)

public struct DevicesStripWidgetView: View {
    public var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    private var slots: [EcosystemDeviceSlot] {
        entry.snapshot.deviceSlots.isEmpty ? EcosystemDeviceSlot.defaultExtendedEcosystem : entry.snapshot.deviceSlots
    }

    public var body: some View {
        switch family {
        case .systemLarge:
            VStack(spacing: 10) {
                AppleDevicesLiquidStripCard(
                    slots: Array(slots.prefix(4)),
                    showLabels: true,
                    compact: false
                )
                BatteryHealthBannerCard(
                    healthPercent: entry.snapshot.healthPercent,
                    subtitle: entry.snapshot.healthSubtitle,
                    compact: false
                )
                if slots.count > 4 {
                    AppleDevicesLiquidStripCard(
                        slots: Array(slots.dropFirst(4).prefix(4)),
                        showLabels: true,
                        compact: true
                    )
                }
            }
            .padding(12)
            .ampifyWidgetBackground()
        default:
            VStack(spacing: 8) {
                AppleDevicesLiquidStripCard(
                    slots: Array(slots.prefix(4)),
                    showLabels: true,
                    compact: true
                )
                BatteryHealthBannerCard(
                    healthPercent: entry.snapshot.healthPercent,
                    subtitle: entry.snapshot.healthSubtitle,
                    compact: true
                )
            }
            .padding(10)
            .ampifyWidgetBackground()
        }
    }
}

// MARK: - 2. Extended Apple Ecosystem Widget (Pencil, Apple TV, iPad, Watch, AirPods)

public struct EcosystemDevicesWidgetView: View {
    public var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    private var slots: [EcosystemDeviceSlot] {
        let all = entry.snapshot.deviceSlots.isEmpty ? EcosystemDeviceSlot.defaultExtendedEcosystem : entry.snapshot.deviceSlots
        // Prioritize iPad, Apple Pencil, Apple Watch, Apple TV Remote, iPhone, AirPods
        let preferredOrder: [EcosystemDeviceSlot.Category] = [.iPad, .applePencil, .appleWatch, .appleTV, .iPhone, .airPods, .mac, .mouse]
        var ordered: [EcosystemDeviceSlot] = []
        for cat in preferredOrder {
            if let match = all.first(where: { $0.category == cat }) {
                ordered.append(match)
            }
        }
        return ordered.isEmpty ? all : ordered
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(slots.prefix(2)) { slot in
                        LiquidDeviceSilhouetteView(slot: slot, showLabel: true, compact: true)
                    }
                }
            }
            .padding(10)
            .ampifyWidgetBackground()
        case .systemLarge:
            VStack(spacing: 10) {
                AppleDevicesLiquidStripCard(
                    slots: Array(slots.prefix(4)),
                    showLabels: true,
                    compact: false
                )
                if slots.count > 4 {
                    AppleDevicesLiquidStripCard(
                        slots: Array(slots.dropFirst(4).prefix(4)),
                        showLabels: true,
                        compact: false
                    )
                }
            }
            .padding(12)
            .ampifyWidgetBackground()
        default:
            AppleDevicesLiquidStripCard(
                slots: Array(slots.prefix(4)),
                showLabels: true,
                compact: false
            )
            .padding(10)
            .ampifyWidgetBackground()
        }
    }
}

// MARK: - 3. "What's Using Power" Live App Wattage Widget (Medium & Large)

public struct AppPowerWidgetView: View {
    public var entry: SnapshotEntry

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    private var convertedEntries: [AppEnergyEntry] {
        let items = entry.snapshot.appPowerItems.isEmpty ? WidgetAppPowerItem.defaultItems : entry.snapshot.appPowerItems
        return items.enumerated().map { idx, item in
            let kind: AppEnergyEntry.EntryKind = item.isMacOSRow ? .macOSItself : (item.isEverythingElseRow ? .everythingElse : .application)
            return AppEnergyEntry(
                pid: pid_t(100 + idx),
                bundleIdentifier: nil,
                name: item.name,
                watts: item.watts,
                cpuPercent: 1.0,
                extraMinutesIfQuit: nil,
                kind: kind
            )
        }
    }

    public var body: some View {
        WhatsUsingPowerSectionView(
            entries: convertedEntries,
            compact: true,
            allowAppActions: false
        )
        .padding(12)
        .ampifyWidgetBackground()
    }
}

// MARK: - 4. Primary Battery & 80% Hold Widget (Small & Medium)

public struct BatteryWidgetView: View {
    public var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                widgetBatteryGlyph(width: 34, height: 15)
                Spacer()
                Text(entry.snapshot.badgeText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("\(entry.snapshot.percentage)%")
                .font(.system(size: 26, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(entry.snapshot.healthLine)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)

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
        .padding(12)
        .ampifyWidgetBackground()
    }

    private var mediumBody: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    widgetBatteryGlyph(width: 38, height: 16)
                    Text("\(entry.snapshot.percentage)%")
                        .font(.system(size: 24, weight: .medium))
                        .monospacedDigit()
                }

                Text(entry.snapshot.badgeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                Text(entry.snapshot.headline)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                widgetRow(icon: "heart", title: "Health", value: "\(entry.snapshot.healthPercent)% · \(entry.snapshot.cycleCount)c")
                widgetRow(icon: "chart.bar", title: "Above 80%", value: String(format: "%.1fh / wk", entry.snapshot.hoursAbove80ThisWeek))

                if let devName = entry.snapshot.primaryDeviceName,
                   let devPct = entry.snapshot.primaryDevicePercent {
                    widgetRow(icon: "iphone", title: devName, value: "\(devPct)%")
                }
                if let wName = entry.snapshot.watchName,
                   let wPct = entry.snapshot.watchPercent {
                    widgetRow(icon: "applewatch", title: wName, value: "\(wPct)%")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .ampifyWidgetBackground()
    }

    private func widgetRow(icon: String, title: String, value: String) -> some View {
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
                .foregroundStyle(.primary)
        }
    }

    private func widgetBatteryGlyph(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.1)
                    .frame(width: width, height: height)

                let inner = max(0, width - 4)
                let fillW = inner * CGFloat(min(100, max(0, entry.snapshot.percentage))) / 100.0
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(nsColor: .systemGreen))
                    .frame(width: fillW, height: max(4, height - 4))
                    .padding(.leading, 2)

                if let lim = entry.snapshot.activeLimit, lim > 0 && lim < 100 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.65))
                        .frame(width: 1.2, height: height - 2)
                        .offset(x: 2 + inner * CGFloat(lim) / 100.0)
                }
            }
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.primary.opacity(0.35))
                .frame(width: 2, height: height * 0.42)
        }
    }
}

// MARK: - 5. Power & Longevity Widget

public struct PowerLongevityWidgetView: View {
    public var entry: SnapshotEntry

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.heart")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Battery Health")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f W", entry.snapshot.powerWatts))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(entry.snapshot.healthPercent)%")
                    .font(.system(size: 24, weight: .medium))
                    .monospacedDigit()
                Text("Max Capacity")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Text(entry.snapshot.healthSubtitle)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(entry.snapshot.badgeText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color(nsColor: .systemGreen))
        }
        .padding(12)
        .ampifyWidgetBackground()
    }
}

// MARK: - Widget Configurations & Bundle

public struct AmpifyDevicesStripWidget: Widget {
    public let kind: String = "AmpifyDevicesStripWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            DevicesStripWidgetView(entry: entry)
        }
        .configurationDisplayName("Apple Devices Liquid Strip")
        .description("Liquid-wave battery silhouettes for iPhone, iPad, Apple Watch & AirPods plus Mac battery health.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

public struct AmpifyEcosystemWidget: Widget {
    public let kind: String = "AmpifyEcosystemWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            EcosystemDevicesWidgetView(entry: entry)
        }
        .configurationDisplayName("Apple Ecosystem & Accessories")
        .description("Liquid-wave battery levels across your connected iPhone, Apple Watch, AirPods, Mouse, Keyboard, and Mac.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

public struct AmpifyAppPowerWidget: Widget {
    public let kind: String = "AmpifyAppPowerWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            AppPowerWidgetView(entry: entry)
        }
        .configurationDisplayName("What's Using Power")
        .description("Live wattage going to your apps right now with proportional power bars for top apps and macOS.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

public struct AmpifyBatteryWidget: Widget {
    public let kind: String = "AmpifyBatteryWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery & 80% Hold")
        .description("Live Mac battery percentage, 80% hold marker, health capacity, and paired iPhone & Apple Watch levels.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct AmpifyPowerLongevityWidget: Widget {
    public let kind: String = "AmpifyPowerLongevityWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            PowerLongevityWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery Health & Power")
        .description("Monitor maximum battery capacity %, normal wear status, cycle count, and live wattage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
public struct AmpifyWidgetsBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        AmpifyDevicesStripWidget()
        AmpifyEcosystemWidget()
        AmpifyAppPowerWidget()
        AmpifyBatteryWidget()
        AmpifyPowerLongevityWidget()
    }
}
