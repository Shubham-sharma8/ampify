import SwiftUI
import AppKit
#if canImport(BatteryCore)
import BatteryCore
#endif

public struct PanelView: View {
    @ObservedObject public var store: BatteryStore
    public var openDashboard: (DashboardSection) -> Void

    public init(store: BatteryStore, openDashboard: @escaping (DashboardSection) -> Void) {
        self.store = store
        self.openDashboard = openDashboard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection
            if let insight = store.activeInsight {
                insightBanner(insight)
            }
            chargeLimitCard
            devicesLiquidAndHealthSection
            powerSwitchesCard
            energyAndAwakeSnippet
            footerBar
        }
        .padding(12)
        .frame(width: 376)
        .background(AmpifyTheme.windowBackground)
    }

    private func insightBanner(_ insight: BatteryInsight) -> some View {
        AmpifyCard(padding: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: insight.symbol)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AmpifyTheme.caution)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(insight.detail)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var headerSection: some View {
        AmpifyCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    BatteryGlyphView(
                        percentage: store.reading.percentage,
                        limit: store.reading.activeChargeLimit,
                        isCharging: store.reading.isCharging,
                        isPluggedIn: store.reading.isPluggedIn,
                        width: 44,
                        height: 20
                    )
                    Text("\(store.reading.percentage)%")
                        .font(.system(size: 22, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    AmpifyStatusPill(
                        text: store.statusExplanation.badgeText,
                        color: AmpifyTheme.toneColor(store.statusExplanation.tone)
                    )

                    Spacer()

                    Button {
                        store.detailLevel = (store.detailLevel == .simple) ? .technical : .simple
                    } label: {
                        Text(store.detailLevel.label)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(AmpifyTheme.subtleFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Switch between Simple plain-English sentences and Technical electrical metrics")
                }

                Text(store.statusExplanation.headline)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if store.detailLevel == .simple {
                    Text(store.statusExplanation.detail)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(store.statusExplanation.technicalLine)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var chargeLimitCard: some View {
        AmpifyCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold Charge at 80%")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Prevents high-voltage wear while plugged in at your desk")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.limitEnabled && store.fullChargeSession == nil },
                            set: { store.setChargeLimitEnabled($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Divider()

                if let session = store.fullChargeSession {
                    HStack {
                        Image(systemName: "bolt.badge.clock")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("Charging to 100% once · \(session.restoreSummary)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore 80%") {
                            store.endFullChargeSession()
                        }
                        .controlSize(.small)
                        .font(.system(size: 11, weight: .medium))
                    }
                } else {
                    HStack(spacing: 6) {
                        Menu {
                            Button("Restore 80% when unplugged") {
                                store.startFullChargeOnce(restoreOnUnplug: true, restoreWhenFull: false, hours: 12)
                            }
                            Button("Restore 80% as soon as full (100%)") {
                                store.startFullChargeOnce(restoreOnUnplug: true, restoreWhenFull: true, hours: 12)
                            }
                            Button("Restore 80% after 4 hours") {
                                store.startFullChargeOnce(restoreOnUnplug: false, restoreWhenFull: false, hours: 4)
                            }
                        } label: {
                            Label("Charge to 100% Once", systemImage: "battery.100percent.bolt")
                                .font(.system(size: 11.5, weight: .regular))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        Spacer()

                        if let nextTrip = store.upcomingTrips.first {
                            Text("Trip: \(nextTrip.title)")
                                .font(.system(size: 10.5, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var metricsStrip: some View {
        HStack(spacing: 8) {
            AmpifyMetricTile(
                label: "Health",
                value: "\(store.reading.healthPercent)%",
                caption: "\(store.reading.cycleCount) cycles"
            )
            AmpifyMetricTile(
                label: "Temperature",
                value: String(format: "%.1f °C", store.reading.temperatureCelsius),
                caption: store.reading.thermalBand.label
            )
            AmpifyMetricTile(
                label: "Power",
                value: String(format: "%.1f W", store.reading.batteryWatts),
                caption: store.reading.adapterWatts.map { "\($0)W adapter" } ?? (store.reading.isPluggedIn ? "Wall power" : "Battery")
            )
        }
    }

    private var powerSwitchesCard: some View {
        AmpifyCard(padding: 10) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(KeepAwakeDuration.allCases, id: \.self) { mode in
                        Button {
                            store.setKeepAwake(mode)
                        } label: {
                            HStack {
                                Text("Keep Awake: \(mode.rawValue)")
                                if store.keepAwakeDuration == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: store.keepAwakeDuration == .off ? "cup.and.saucer" : "cup.and.saucer.fill")
                            .font(.system(size: 11.5, weight: .regular))
                        Text(store.keepAwakeDuration == .off ? "Keep Awake: Off" : "Awake: \(store.keepAwakeDuration.rawValue)")
                            .font(.system(size: 11.5, weight: .regular))
                    }
                }
                .menuStyle(.borderlessButton)

                Divider()
                    .frame(height: 14)

                Button {
                    store.toggleLowPowerMode()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: store.lowPowerModeEnabled ? "leaf.fill" : "leaf")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(store.lowPowerModeEnabled ? AmpifyTheme.caution : .secondary)
                        Text(store.lowPowerModeEnabled ? "Low Power: On" : "Low Power: Off")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var devicesLiquidAndHealthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppleDevicesLiquidStripCard(
                slots: store.ecosystemDeviceSlots,
                showLabels: true,
                compact: true,
                onSelectSlot: { _ in
                    openDashboard(.devices)
                }
            )

            Button {
                openDashboard(.health)
            } label: {
                BatteryHealthBannerCard(
                    healthPercent: store.reading.healthPercent,
                    subtitle: store.healthStatusSubtitle,
                    compact: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var energyAndAwakeSnippet: some View {
        VStack(alignment: .leading, spacing: 8) {
            WhatsUsingPowerSectionView(
                entries: store.topEnergyApps,
                compact: true,
                allowAppActions: true,
                onQuitApp: { pid in
                    store.quitApp(pid: pid)
                }
            )

            if let holder = store.awakeHolders.first {
                AmpifyCard(padding: 9) {
                    HStack {
                        Image(systemName: holder.category.sfSymbol)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("Keeping Mac awake: \(holder.processName)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(holder.formattedDuration)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button {
                openDashboard(.now)
            } label: {
                Label("Open Dashboard", systemImage: "macwindow")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Button {
                store.exportShareableSnapshotCard()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Export shareable battery snapshot card (PNG)")

            Button {
                openDashboard(.widgets)
            } label: {
                Image(systemName: "rectangle.grid.2x2")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Desktop Widgets")

            Button {
                store.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh readings")

            Button {
                openDashboard(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Divider()
                .frame(height: 12)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .regular))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}
