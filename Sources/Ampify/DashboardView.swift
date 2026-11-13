import SwiftUI
import Charts
import AppKit
#if canImport(BatteryCore)
import BatteryCore
#endif

public struct DashboardView: View {
    @ObservedObject public var store: BatteryStore

    public init(store: BatteryStore) {
        self.store = store
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailPane
        }
        .frame(minWidth: 720, minHeight: 500)
        .background(AmpifyTheme.windowBackground)
        .sheet(isPresented: $store.showOnboardingSheet) {
            OnboardingView(store: store)
        }
        .sheet(isPresented: $store.showDiagnosticsSheet) {
            DiagnosticsSheetView(store: store)
        }
        .onAppear {
            if !store.hasCompletedOnboarding {
                store.showOnboardingSheet = true
            }
        }
    }

    // MARK: - Helium-Style Calm Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App Identity & Live Pill
            HStack(spacing: 10) {
                if let iconURL = AmpifyResourceBundle.url(forResource: "AmpifyIcon-Canva", withExtension: "png"),
                   let nsImg = NSImage(contentsOf: iconURL) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Image(systemName: "battery.75percent")
                        .font(.system(size: 16, weight: .regular))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Ampify")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(store.reading.percentage)% · \(store.statusExplanation.badgeText)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            Divider()
                .padding(.horizontal, 10)

            // Navigation items
            VStack(alignment: .leading, spacing: 3) {
                ForEach(DashboardSection.allCases) { section in
                    sidebarButton(for: section)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Quick Simple vs Technical mode switch at bottom of sidebar
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                HStack {
                    Text("Language")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $store.detailLevel) {
                        ForEach(DetailLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(width: 128)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 218)
        .background(AmpifyTheme.surfaceBackground.opacity(0.55))
    }

    private func sidebarButton(for section: DashboardSection) -> some View {
        let isSelected = store.selectedSection == section
        return Button {
            store.selectedSection = section
        } label: {
            HStack(spacing: 9) {
                Image(systemName: section.sfSymbol)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 18)
                Text(section.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.primary)
                Spacer()
                if section == .devices && !store.appleDevices.isEmpty {
                    Text("\(store.appleDevices.count)")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(AmpifyTheme.subtleFill)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            topHeaderBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch store.selectedSection {
                    case .now:
                        nowTabContent
                    case .health:
                        healthTabContent
                    case .habits:
                        habitsTabContent
                    case .energy:
                        energyTabContent
                    case .devices:
                        devicesTabContent
                    case .widgets:
                        widgetsTabContent
                    case .alerts:
                        alertsTabContent
                    case .settings:
                        settingsTabContent
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedSection.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(store.selectedSection.subtitle)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            AmpifyStatusPill(
                text: store.statusExplanation.badgeText,
                color: AmpifyTheme.toneColor(store.statusExplanation.tone)
            )
            Button {
                store.exportShareableSnapshotCard()
            } label: {
                Label("Share Card", systemImage: "camera.viewfinder")
                    .font(.system(size: 11.5, weight: .regular))
            }
            .controlSize(.small)
            .help("Save a shareable PNG battery snapshot card")

            Button {
                store.refreshAll()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 11.5, weight: .regular))
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 1. NOW TAB

    private var nowTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let insight = store.activeInsight {
                AmpifyCard {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: insight.symbol)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AmpifyTheme.caution)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(insight.detail)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        AmpifyStatusPill(
                            text: "Live Insight",
                            color: AmpifyTheme.caution
                        )
                    }
                }
            }

            // Live Hero Card
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        BatteryGlyphView(
                            percentage: store.reading.percentage,
                            limit: store.reading.activeChargeLimit,
                            isCharging: store.reading.isCharging,
                            isPluggedIn: store.reading.isPluggedIn,
                            width: 58,
                            height: 26
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(store.reading.percentage)%")
                                    .font(.system(size: 26, weight: .medium))
                                    .monospacedDigit()
                                Text(store.statusExplanation.headline)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            Text(store.detailLevel == .simple ? store.statusExplanation.detail : store.statusExplanation.technicalLine)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Divider()

                    HStack(spacing: 10) {
                        AmpifyMetricTile(
                            label: "Charge Limit",
                            value: store.reading.activeChargeLimit.map { "\($0)% Active" } ?? "Off (100%)",
                            caption: store.reading.isRunningOffPowerAdapter ? "Running off adapter" : (store.reading.isPluggedIn ? "Plugged in" : "On battery")
                        )
                        AmpifyMetricTile(
                            label: "Battery Health",
                            value: "\(store.reading.healthPercent)%",
                            caption: "\(store.reading.nominalCapacitymAh) / \(store.reading.designCapacitymAh) mAh"
                        )
                        AmpifyMetricTile(
                            label: "Cycle Count",
                            value: "\(store.reading.cycleCount)",
                            caption: "Rated for \(store.reading.designCycleCount) cycles"
                        )
                        AmpifyMetricTile(
                            label: "Temperature",
                            value: String(format: "%.1f °C", store.reading.temperatureCelsius),
                            caption: store.reading.thermalBand.label
                        )
                    }
                }
            }

            // Apple Ecosystem Liquid-Wave Strip + Battery Health Summary Banner
            HStack(alignment: .center, spacing: 14) {
                AppleDevicesLiquidStripCard(
                    slots: store.ecosystemDeviceSlots,
                    showLabels: true,
                    compact: false,
                    onSelectSlot: { _ in
                        store.selectedSection = .devices
                    }
                )
                .frame(maxWidth: .infinity)

                BatteryHealthBannerCard(
                    healthPercent: store.reading.healthPercent,
                    subtitle: store.healthStatusSubtitle,
                    compact: false
                )
                .frame(width: 310)
            }

            // 3-Node Power Flow View (Adapter -> This Mac -> Battery) + Charger Memory & Verdict
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AmpifySectionHeader(
                            title: "Live Power Flow",
                            subtitle: store.powerFlow.summaryText
                        )
                        Spacer()
                        AmpifyStatusPill(
                            text: store.powerFlow.verdict.rawValue,
                            color: (store.powerFlow.verdict == .weak || store.powerFlow.verdict == .slow) ? AmpifyTheme.caution : AmpifyTheme.good
                        )
                    }

                    HStack(spacing: 10) {
                        powerFlowNode(
                            icon: store.reading.isPluggedIn ? "powerplug" : "powerplug.slash",
                            title: store.reading.adapterWatts.map { "\($0)W Adapter" } ?? "Power Adapter",
                            value: store.reading.isPluggedIn ? String(format: "%.1f W", store.powerFlow.fromChargerWatts) : "Unplugged",
                            caption: store.biggestSeenChargerWatts > 0 ? "Biggest seen: \(store.biggestSeenChargerWatts)W" : "No adapter history yet"
                        )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)

                        powerFlowNode(
                            icon: "laptopcomputer",
                            title: "This Mac Uses",
                            value: String(format: "%.1f W", store.powerFlow.macUsesWatts),
                            caption: store.topEnergyApps.first.map { "Top: \($0.name)" } ?? "System & display"
                        )

                        Image(systemName: store.reading.isCharging ? "arrow.right" : (store.reading.isPluggedIn ? "pause" : "arrow.left"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)

                        powerFlowNode(
                            icon: store.reading.isCharging ? "battery.100percent.bolt" : "battery.75percent",
                            title: "Battery Cell",
                            value: String(format: "%.1f W", abs(store.powerFlow.batteryWatts)),
                            caption: store.reading.isCharging ? "Charging into battery" : (store.reading.isPluggedIn ? "Resting on wall power" : "Draining battery")
                        )
                    }
                }
            }

            // Charge Limit & Charge to 100% Once Card
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AmpifySectionHeader(
                            title: "80% Charge Limit",
                            subtitle: "Stops charging at 80% and runs your Mac directly from wall power."
                        )
                        Spacer()
                        Toggle(
                            "Hold at 80%",
                            isOn: Binding(
                                get: { store.limitEnabled && store.fullChargeSession == nil },
                                set: { store.setChargeLimitEnabled($0) }
                            )
                        )
                        .toggleStyle(.switch)
                        .font(.system(size: 12, weight: .regular))
                    }

                    if !store.reading.isLimitSupported, let reason = store.reading.limitUnavailableReason {
                        Text("Note: \(reason)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Need a full battery before heading out?")
                                .font(.system(size: 12, weight: .medium))
                            Text(store.fullChargeSession.map { "Active: charging to 100% (\($0.restoreSummary))." } ?? "Charge to 100% once and let Ampify restore your 80% limit automatically.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.fullChargeSession != nil {
                            Button("Restore 80% Limit Now") {
                                store.endFullChargeSession()
                            }
                            .controlSize(.small)
                        } else {
                            Button("Until Unplugged") {
                                store.startFullChargeOnce(restoreOnUnplug: true, restoreWhenFull: false, hours: 12)
                            }
                            .controlSize(.small)

                            Button("Until 100%") {
                                store.startFullChargeOnce(restoreOnUnplug: true, restoreWhenFull: true, hours: 12)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            // 3-Hour History Strip Chart & Limit Watchdog
            HStack(alignment: .top, spacing: 14) {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Last 3 Hours",
                            subtitle: "Recent charge level and 80% hold line"
                        )
                        Chart {
                            RuleMark(y: .value("Limit", 80))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            ForEach(store.recentHistory) { pt in
                                LineMark(
                                    x: .value("Time", pt.timestamp),
                                    y: .value("Battery %", pt.percentage)
                                )
                                .foregroundStyle(AmpifyTheme.good)
                                AreaMark(
                                    x: .value("Time", pt.timestamp),
                                    y: .value("Battery %", pt.percentage)
                                )
                                .foregroundStyle(AmpifyTheme.good.opacity(0.10))
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 135)
                    }
                }

                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Why macOS Sometimes Passes 80%",
                            subtitle: "Limit Watchdog & Powerd Calibration Probe"
                        )
                        ForEach(LimitWatchdog.SlipCause.allCases) { cause in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(cause.title)")
                                    .font(.system(size: 11.5, weight: .medium))
                                Text(cause.explanation)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func powerFlowNode(icon: String, title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(caption)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AmpifyTheme.subtleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
        )
    }

    // MARK: - 2. HEALTH TAB

    private var healthTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AmpifySectionHeader(
                            title: "Battery Longevity & Service Threshold",
                            subtitle: store.healthProjection.headline
                        )
                        Spacer()
                        Button {
                            ReportPDFGenerator.exportHealthReport(store: store)
                        } label: {
                            Label("Export 1-Page PDF Report", systemImage: "doc.richtext")
                                .font(.system(size: 11.5, weight: .regular))
                        }
                        .controlSize(.small)
                    }

                    Text(store.healthProjection.detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        AmpifyMetricTile(
                            label: "Maximum Capacity",
                            value: "\(store.reading.healthPercent)%",
                            caption: "\(store.reading.nominalCapacitymAh) mAh current full charge"
                        )
                        AmpifyMetricTile(
                            label: "Original Design Capacity",
                            value: "\(store.reading.designCapacitymAh) mAh",
                            caption: "Factory rating when new"
                        )
                        AmpifyMetricTile(
                            label: "Cycle Progress",
                            value: "\(store.reading.cycleCount) / \(store.reading.designCycleCount)",
                            caption: "\(max(0, store.reading.designCycleCount - store.reading.cycleCount)) cycles before rated limit"
                        )
                        AmpifyMetricTile(
                            label: "Annual Fade Rate",
                            value: String(format: "~%.1f%% / yr", store.healthProjection.dropPerYearPercent),
                            caption: "80% is Apple's service line"
                        )
                    }
                }
            }

            AmpifyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        AmpifySectionHeader(
                            title: "Capacity Trend vs 80% Service Line",
                            subtitle: "Tracked from local daily capacity snapshots"
                        )
                        Spacer()
                        Picker("", selection: $store.healthTimeRange) {
                            ForEach(HealthTimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 210)
                    }

                    Chart {
                        RuleMark(y: .value("80% Service Line", 80))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(AmpifyTheme.caution)
                            .annotation(position: .top, alignment: .leading) {
                                Text("80% Apple Service Threshold")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                        ForEach(store.healthSamples) { sample in
                            LineMark(
                                x: .value("Date", sample.date),
                                y: .value("Health %", sample.healthPercent)
                            )
                            .foregroundStyle(AmpifyTheme.good)
                            PointMark(
                                x: .value("Date", sample.date),
                                y: .value("Health %", sample.healthPercent)
                            )
                            .foregroundStyle(AmpifyTheme.good)
                        }
                    }
                    .chartYScale(domain: 70...102)
                    .frame(height: 170)
                }
            }

            // Apple Out-of-Warranty Battery Replacement Cost (service-prices.json)
            AmpifyCard {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Out-of-Warranty Battery Replacement Estimate")
                            .font(.system(size: 13, weight: .medium))
                        Text("Model \(store.serviceEstimate.modelIdentifier) · Official Apple Store out-of-warranty battery service price (read offline from bundled service-prices.json, as of \(store.serviceEstimate.asOfDate)). Free with active AppleCare+ below 80% health.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Region", selection: $store.selectedRegionCode) {
                        Text("US (USD)").tag("US")
                        Text("CA (CAD)").tag("CA")
                        Text("UK (GBP)").tag("GB")
                        Text("DE (EUR)").tag("DE")
                        Text("FR (EUR)").tag("FR")
                        Text("JP (JPY)").tag("JP")
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 105)

                    Text(store.serviceEstimate.formattedPrice)
                        .font(.system(size: 18, weight: .medium))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AmpifyTheme.subtleFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - 3. HABITS TAB

    private var habitsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmpifyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        AmpifySectionHeader(
                            title: "Weekly Time Above 80% Charge",
                            subtitle: store.weekSummary.plainSummary
                        )
                        Spacer()
                        AmpifyStatusPill(
                            text: store.weekSummary.grade.rawValue,
                            color: store.weekSummary.grade == .gentle ? AmpifyTheme.good : AmpifyTheme.caution
                        )
                    }

                    Chart(store.weekSummary.days) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Hours > 80%", day.hoursAbove80)
                        )
                        .foregroundStyle(day.hoursAbove80 > 3.0 ? AmpifyTheme.caution : AmpifyTheme.good)
                        .cornerRadius(3)
                    }
                    .frame(height: 150)

                    HStack(spacing: 10) {
                        AmpifyMetricTile(
                            label: "Total Hours > 80% (7d)",
                            value: String(format: "%.1f hrs", store.weekSummary.totalHoursAbove80),
                            caption: "Lower means less voltage stress"
                        )
                        AmpifyMetricTile(
                            label: "While Plugged In",
                            value: String(format: "%.1f hrs", store.weekSummary.pluggedHoursAbove80),
                            caption: "Preventable by holding at 80%"
                        )
                        AmpifyMetricTile(
                            label: "Daily Average",
                            value: String(format: "%.1f hrs/day", store.weekSummary.averageDailyHoursAbove80),
                            caption: "Goal: under 1.0 hr/day"
                        )
                    }
                }
            }

            // Smart Top-Up: Calendar Trip Trigger + Learned Departure Schedule
            HStack(alignment: .top, spacing: 14) {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            AmpifySectionHeader(
                                title: "Before a Trip (Calendar)",
                                subtitle: "Charges to 100% the evening before travel and restores 80% on unplug."
                            )
                            Spacer()
                            Toggle("", isOn: $store.tripTopUpEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }

                        Divider()

                        if store.upcomingTrips.isEmpty {
                            HStack {
                                Text("No travel events detected in the next 48 hours.")
                                    .font(.system(size: 11.5, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Check Calendar") {
                                    store.requestCalendarPermissionAndScan()
                                }
                                .controlSize(.small)
                            }
                        } else {
                            ForEach(store.upcomingTrips) { trip in
                                HStack {
                                    Image(systemName: "airplane.departure")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trip.title)
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Matched '\(trip.matchedKeyword)' · 100% top-up scheduled")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            AmpifySectionHeader(
                                title: "Before Your Usual Departure",
                                subtitle: "Learns when you unplug on weekdays and tops up right before you leave."
                            )
                            Spacer()
                            Toggle("", isOn: $store.smartDepartureTopUpEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }

                        Divider()

                        ForEach(store.departurePredictions.prefix(4), id: \.weekday) { pred in
                            HStack {
                                Text(weekdayName(pred.weekday))
                                    .font(.system(size: 11.5, weight: .medium))
                                    .frame(width: 82, alignment: .leading)
                                Text("Usually unplugs around \(pred.formattedTime)")
                                    .font(.system(size: 11.5, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Top-up \(pred.topUpStartFormattedTime)")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 4. ENERGY TAB

    private var energyTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Quick Power Switches
            AmpifyCard {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Power Switches")
                            .font(.system(size: 13, weight: .medium))
                        Text("Keep Awake automatically releases at 10% on battery so your Mac never dies unexpectedly.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Keep Awake", selection: Binding(
                        get: { store.keepAwakeDuration },
                        set: { store.setKeepAwake($0) }
                    )) {
                        ForEach(KeepAwakeDuration.allCases, id: \.self) { mode in
                            Text("Keep Awake: \(mode.rawValue)").tag(mode)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 195)

                    Button {
                        store.toggleLowPowerMode()
                    } label: {
                        Label(
                            store.lowPowerModeEnabled ? "Low Power Mode: On" : "Low Power Mode: Off",
                            systemImage: store.lowPowerModeEnabled ? "leaf.fill" : "leaf"
                        )
                        .font(.system(size: 11.5, weight: .regular))
                    }
                    .controlSize(.small)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                // Live Per-App Energy Monitor ("What's using power")
                AmpifyCard {
                    WhatsUsingPowerSectionView(
                        entries: store.topEnergyApps,
                        compact: false,
                        allowAppActions: true,
                        onQuitApp: { pid in
                            store.quitApp(pid: pid)
                        }
                    )
                }

                // What's Keeping Your Mac Awake
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "What's Keeping Your Mac Awake",
                            subtitle: "Active IOPM power assertions preventing display or system sleep"
                        )
                        Divider()
                        if store.awakeHolders.isEmpty {
                            Text("Nothing is currently blocking sleep.")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(store.awakeHolders) { holder in
                                HStack {
                                    Image(systemName: holder.category.sfSymbol)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(holder.processName)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(store.detailLevel == .simple ? holder.category.rawValue : "\(holder.assertionType): \(holder.assertionName)")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(holder.formattedDuration)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
            }

            // Unplugged Battery Stretches & Usual Drain + Sleep Drain Tracker
            HStack(alignment: .top, spacing: 14) {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        AmpifySectionHeader(
                            title: "Unplugged Battery Stretches & Usual Drain",
                            subtitle: store.usualDrainSummary
                        )
                        Divider()
                        ForEach(store.batteryStretches) { stretch in
                            HStack {
                                Image(systemName: "battery.75percent")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stretch.summaryLine)
                                        .font(.system(size: 11.5, weight: .regular))
                                    Text(String(format: "Estimated full 100%% → 0%% pace: ~%.1f hrs", stretch.estimatedFullRuntimeHours))
                                        .font(.system(size: 10.5, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                AmpifyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        AmpifySectionHeader(
                            title: "Overnight & Sleep Drain",
                            subtitle: "Battery lost during Mac sleep stretches longer than 30 minutes"
                        )
                        Divider()
                        ForEach(store.sleepEpisodes) { ep in
                            HStack {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Text(ep.summaryLine)
                                    .font(.system(size: 11.5, weight: .regular))
                                Spacer()
                                Text("\(ep.startPercent)% → \(ep.endPercent)%")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. DEVICES TAB

    private var devicesTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Connected Apple Ecosystem Liquid-Wave Showcase
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AmpifySectionHeader(
                            title: "Apple Ecosystem Battery Strip",
                            subtitle: "Live liquid-wave battery levels across your connected Apple & Bluetooth devices"
                        )
                        Spacer()
                        Button {
                            store.refreshDevicesInBackground()
                        } label: {
                            Label(store.isScanningDevices ? "Scanning Wi-Fi…" : "Scan All Devices", systemImage: "wave.3.right")
                                .font(.system(size: 11.5, weight: .regular))
                        }
                        .controlSize(.small)
                        .disabled(store.isScanningDevices)
                    }

                    let allSlots = store.ecosystemDeviceSlots
                    AppleDevicesLiquidStripCard(
                        slots: Array(allSlots.prefix(4)),
                        showLabels: true,
                        compact: false
                    )

                    if allSlots.count > 4 {
                        AppleDevicesLiquidStripCard(
                            slots: Array(allSlots.dropFirst(4).prefix(4)),
                            showLabels: true,
                            compact: false
                        )
                    }

                    BatteryHealthBannerCard(
                        healthPercent: store.reading.healthPercent,
                        subtitle: store.healthStatusSubtitle,
                        compact: false
                    )
                }
            }

            // This Mac Card
            AmpifyCard {
                HStack(spacing: 14) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(Host.current().localizedName ?? "This Mac")
                                .font(.system(size: 13, weight: .medium))
                            AmpifyStatusPill(
                                text: store.statusExplanation.badgeText,
                                color: AmpifyTheme.toneColor(store.statusExplanation.tone)
                            )
                        }
                        Text("\(store.serviceEstimate.modelIdentifier) · Health \(store.reading.healthPercent)% · \(store.reading.cycleCount) cycles · \(String(format: "%.1f °C", store.reading.temperatureCelsius))")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(store.reading.percentage)%")
                        .font(.system(size: 18, weight: .medium))
                        .monospacedDigit()
                }
            }

            // Paired iPhone, iPad & Apple Watch over Wi-Fi / USB
            AmpifyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        AmpifySectionHeader(
                            title: "iPhone, iPad & Apple Watch (Wi-Fi / USB)",
                            subtitle: "Discovered via CoreDevice + MobileDevice framework whenever paired devices are on the same Wi-Fi"
                        )
                        Spacer()
                        Button {
                            store.showAddDeviceGuide.toggle()
                        } label: {
                            Label("Add an iPhone or iPad", systemImage: "plus.circle")
                                .font(.system(size: 11.5, weight: .regular))
                        }
                        .controlSize(.small)

                        Button {
                            store.refreshDevicesInBackground()
                        } label: {
                            Label(store.isScanningDevices ? "Scanning…" : "Scan Now", systemImage: "wave.3.right")
                                .font(.system(size: 11.5, weight: .regular))
                        }
                        .controlSize(.small)
                        .disabled(store.isScanningDevices)
                    }

                    if store.showAddDeviceGuide {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How to see your iPhone, iPad, and paired Apple Watch over Wi-Fi:")
                                .font(.system(size: 11.5, weight: .medium))
                            Text("1. Plug your iPhone or iPad into this Mac with a cable once and tap Trust.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                            Text("2. Open Finder, select your device in the sidebar, and check “Show this iPhone when on Wi-Fi”.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                            Text("3. Unplug — Ampify automatically wakes the wireless CoreDevice link and reads your iPhone and paired Apple Watch over Wi-Fi.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AmpifyTheme.subtleFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
                        )
                    }

                    Divider()

                    if store.appleDevices.isEmpty {
                        Text(store.isScanningDevices
                             ? "Waking Wi-Fi tunnel and reading battery status from paired iPhone & Apple Watch…"
                             : "No paired iPhone, iPad, or Apple Watch responded right now. Click Scan Now or check 'Add an iPhone or iPad'.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(store.appleDevices) { dev in
                            HStack(spacing: 12) {
                                Image(systemName: dev.kind.sfSymbol)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(dev.name)
                                            .font(.system(size: 12.5, weight: .medium))
                                        Text("(\(dev.marketingModel))")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(.secondary)
                                        if dev.batteryPercent <= 20 && !dev.isCharging {
                                            AmpifyStatusPill(text: "Low Battery", color: AmpifyTheme.caution)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        Text(dev.isCharging ? "Charging" : "On battery")
                                        if let health = dev.healthPercent {
                                            Text("· Health \(health)%")
                                        }
                                        if let cycles = dev.cycleCount {
                                            Text("· \(cycles) cycles")
                                        }
                                        if dev.kind == .iPhone {
                                            let est = BatteryServiceCatalog.estimate(
                                                forModel: dev.productType,
                                                regionCode: store.selectedRegionCode
                                            )
                                            Text("· Apple battery service \(est.formattedPrice)")
                                        }
                                        Text("· \(dev.seenAgoText)")
                                    }
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 6) {
                                    if dev.isCharging {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(AmpifyTheme.good)
                                    }
                                    Text("\(dev.batteryPercent)%")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(dev.batteryPercent <= 20 && !dev.isCharging ? AmpifyTheme.caution : .primary)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }

            // Bluetooth Accessories
            AmpifyCard {
                VStack(alignment: .leading, spacing: 10) {
                    AmpifySectionHeader(
                        title: "Bluetooth Accessories",
                        subtitle: "AirPods (Left, Right & Case), Mice, Keyboards, Trackpads & Headphones"
                    )
                    Divider()
                    if store.bluetoothAccessories.isEmpty {
                        Text("No paired Bluetooth accessories found.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(store.bluetoothAccessories) { acc in
                            HStack(spacing: 12) {
                                Image(systemName: acc.kind.sfSymbol)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(acc.name)
                                            .font(.system(size: 12.5, weight: .medium))
                                        if !acc.isConnected {
                                            Text("Paired")
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                        .fill(AmpifyTheme.subtleFill)
                                                )
                                        }
                                    }
                                    Text(acc.detailSummary)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let pct = acc.primaryPercent {
                                    Text("\(pct)%")
                                        .font(.system(size: 15, weight: .medium))
                                        .monospacedDigit()
                                } else {
                                    Text(acc.isConnected ? "Connected" : "Standby")
                                        .font(.system(size: 11.5, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. WIDGETS TAB

    private var widgetsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmpifyCard {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("macOS Desktop & Notification Center Widgets")
                            .font(.system(size: 13.5, weight: .medium))
                        Text("Ampify bundles a native WidgetKit extension (AmpifyWidget.appex) with Small & Medium Desktop Widgets and an interactive Control Center Charge Limit toggle.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.syncWidgetSnapshot()
                    } label: {
                        Label("Sync Widget Snapshot", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11.5, weight: .regular))
                    }
                    .controlSize(.small)

                    Button {
                        store.exportShareableSnapshotCard()
                    } label: {
                        Label("Export Shareable PNG", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11.5, weight: .regular))
                    }
                    .controlSize(.small)
                }
            }

            // Live Previews of Desktop Widgets (Liquid Strip, What's Using Power, Small & Medium)
            HStack(alignment: .top, spacing: 16) {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Apple Devices Liquid Strip Widget",
                            subtitle: "iPhone, iPad, Apple Watch & AirPods + Battery Health"
                        )
                        VStack(spacing: 8) {
                            AppleDevicesLiquidStripCard(
                                slots: store.ecosystemDeviceSlots,
                                showLabels: true,
                                compact: true
                            )
                            BatteryHealthBannerCard(
                                healthPercent: store.reading.healthPercent,
                                subtitle: store.healthStatusSubtitle,
                                compact: true
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }

                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "What's Using Power Widget",
                            subtitle: "Live app wattage and proportional mint-green power bars"
                        )
                        WhatsUsingPowerSectionView(
                            entries: store.topEnergyApps,
                            compact: true,
                            allowAppActions: false
                        )
                        .padding(.vertical, 4)
                    }
                }
            }

            // Extended Apple Ecosystem Widget Preview (only shown if more than 4 devices are connected)
            if store.ecosystemDeviceSlots.count > 4 {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Extended Apple Ecosystem Widget",
                            subtitle: "Additional connected devices shown in Medium & Large widget sizes"
                        )
                        AppleDevicesLiquidStripCard(
                            slots: Array(store.ecosystemDeviceSlots.dropFirst(4).prefix(4)),
                            showLabels: true,
                            compact: true
                        )
                    }
                }
            }

            // Live Previews of Small & Medium Desktop Widgets
            HStack(alignment: .top, spacing: 16) {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Small Desktop Widget",
                            subtitle: "Live percentage, status badge, health & temperature"
                        )
                        DesktopWidgetPreview(snapshot: store.latestWidgetSnapshot, isSmall: true)
                            .frame(width: 170, height: 170)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                    }
                }

                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Medium Desktop Widget",
                            subtitle: "Adds live wattage, cycle count, and paired iPhone / Apple Watch battery"
                        )
                        DesktopWidgetPreview(snapshot: store.latestWidgetSnapshot, isSmall: false)
                            .frame(width: 348, height: 170)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                    }
                }
            }

            // Control Center / Interactive Widget Toggle + How to Add to Desktop
            HStack(alignment: .top, spacing: 14) {
                AmpifyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        AmpifySectionHeader(
                            title: "Interactive Charge Limit Control",
                            subtitle: "Toggle 80% Hold vs 100% Full Charge directly from Control Center or your Desktop"
                        )
                        Divider()
                        HStack(spacing: 12) {
                            Image(systemName: store.limitEnabled ? "battery.75percent" : "battery.100percent.bolt")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(store.limitEnabled ? AmpifyTheme.good : .secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hold at 80%")
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(store.limitEnabled && store.fullChargeSession == nil ? "Active · Holding at 80% on wall power" : "Charging to 100%")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(store.limitEnabled && store.fullChargeSession == nil ? "Switch to 100%" : "Enable 80% Hold") {
                                if store.limitEnabled && store.fullChargeSession == nil {
                                    store.startFullChargeOnce(restoreOnUnplug: true, restoreWhenFull: false, hours: 12)
                                } else {
                                    store.setChargeLimitEnabled(true)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }

                AmpifyCard {
                    VStack(alignment: .leading, spacing: 6) {
                        AmpifySectionHeader(
                            title: "How to Add to Your Mac Desktop",
                            subtitle: "Works on macOS Sonoma, Sequoia & Tahoe"
                        )
                        Divider()
                        Text("1. Right-click anywhere on your Mac Desktop and choose “Edit Widgets…”.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("2. Search for “Ampify” in the widget gallery.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("3. Drag the Small or Medium Ampify Battery widget onto your desktop or Notification Center.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 7. ALERTS TAB

    private var alertsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    AmpifySectionHeader(
                        title: "Calm Notification Rules",
                        subtitle: "Quiet notifications that only fire when an action can save battery health or runtime"
                    )
                    Divider()
                    Toggle("Notify when holding at the 80% charge limit", isOn: $store.alertThresholds.notifyWhenLimitReached)
                        .font(.system(size: 12, weight: .regular))
                    Toggle("Notify when battery temperature exceeds \(Int(store.alertThresholds.warmThresholdCelsius)) °C while charging", isOn: $store.alertThresholds.notifyOnWarmBattery)
                        .font(.system(size: 12, weight: .regular))
                    Toggle("Notify when plugged in above 80% for more than \(Int(store.alertThresholds.maxHoursAbove80PerDay)) hours in a day", isOn: $store.alertThresholds.notifyOnHeavyPluggedInHours)
                        .font(.system(size: 12, weight: .regular))
                    Toggle("Notify if overnight sleep loses \(store.alertThresholds.sleepDrainPercentThreshold)% or more", isOn: $store.alertThresholds.notifyOnOvernightSleepDrain)
                        .font(.system(size: 12, weight: .regular))
                    Toggle("Notify when a paired iPhone, Watch, or AirPods drops below \(store.alertThresholds.lowDevicePercentThreshold)%", isOn: $store.alertThresholds.notifyOnLowDeviceBattery)
                        .font(.system(size: 12, weight: .regular))
                }
            }

            AmpifyCard {
                VStack(alignment: .leading, spacing: 10) {
                    AmpifySectionHeader(
                        title: "Recent Alert History",
                        subtitle: "Local log of quiet notifications"
                    )
                    Divider()
                    if store.alertLog.isEmpty {
                        Text("No alerts triggered yet — your battery is operating within calm limits.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(store.alertLog) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.system(size: 12, weight: .medium))
                                Text(entry.message)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 8. SETTINGS TAB

    private var settingsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmpifyCard {
                VStack(alignment: .leading, spacing: 12) {
                    AmpifySectionHeader(
                        title: "Menu Bar & Interface",
                        subtitle: "Customize how Ampify appears in the macOS menu bar"
                    )
                    Divider()
                    HStack {
                        Text("Menu Bar Readout")
                            .font(.system(size: 12, weight: .regular))
                        Spacer()
                        Picker("", selection: $store.menuBarStyle) {
                            ForEach(MenuBarStyle.allCases, id: \.self) { style in
                                Text(style.label).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    HStack {
                        Text("Explanation Style")
                            .font(.system(size: 12, weight: .regular))
                        Spacer()
                        Picker("", selection: $store.detailLevel) {
                            Text("Simple (Plain English)").tag(DetailLevel.simple)
                            Text("Technical (Watts, V, A, mAh)").tag(DetailLevel.technical)
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    HStack {
                        Text("Launch Ampify at Login")
                            .font(.system(size: 12, weight: .regular))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.launchAtLoginEnabled },
                            set: { store.launchAtLoginEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
            }

            AmpifyCard {
                VStack(alignment: .leading, spacing: 10) {
                    AmpifySectionHeader(
                        title: "Calendar Trip Keywords",
                        subtitle: "Events matching any of these words trigger a 100% top-up the evening before"
                    )
                    TextField("Keywords", text: $store.tripKeywordsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, weight: .regular))
                    Toggle("Also top up to 100% before any all-day Calendar event", isOn: $store.tripIncludeAllDayEvents)
                        .font(.system(size: 12, weight: .regular))
                }
            }

            AmpifyCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Diagnostics & Shareable Snapshot")
                            .font(.system(size: 13, weight: .medium))
                        Text("Inspect raw IOKit / PowerUI / CoreDevice state or export a clean PNG snapshot card.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("View Diagnostics…") {
                        store.showDiagnosticsSheet = true
                    }
                    .controlSize(.small)

                    Button("Export Snapshot PNG…") {
                        store.exportShareableSnapshotCard()
                    }
                    .controlSize(.small)
                }
            }

            AmpifyCard {
                HStack(spacing: 14) {
                    if let logoURL = AmpifyResourceBundle.url(forResource: "AmpifyIcon-Canva", withExtension: "png"),
                       let nsImg = NSImage(contentsOf: logoURL) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ampify 1.6.3")
                            .font(.system(size: 13.5, weight: .medium))
                        Text("A calm macOS battery longevity and charge-limit utility with Cogify Helium System UI.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No background root helper required · 100% local IOKit, CoreDevice & PowerUI integration.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Show Welcome Guide") {
                        store.showOnboardingSheet = true
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1 && weekday <= symbols.count else { return "Weekday" }
        return symbols[weekday - 1]
    }
}

// MARK: - Live Desktop Widget Preview & Diagnostics Sheet

struct DesktopWidgetPreview: View {
    let snapshot: WidgetSnapshot
    let isSmall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: snapshot.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Ampify")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let limit = snapshot.activeLimit {
                    Text("\(limit)% Hold")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AmpifyTheme.good)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(AmpifyTheme.good.opacity(0.14))
                        )
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(snapshot.percentage)%")
                    .font(.system(size: isSmall ? 28 : 32, weight: .medium))
                    .monospacedDigit()
                if !isSmall {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.badgeText)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(snapshot.headline)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if isSmall {
                Text(snapshot.headline)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Divider()

            HStack(spacing: 12) {
                Label("\(snapshot.healthPercent)%", systemImage: "heart")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.secondary)
                Label("\(snapshot.cycleCount) cyc", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.secondary)
                if !isSmall {
                    Label(String(format: "%.1fW", snapshot.powerWatts), systemImage: "bolt")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                    if let devName = snapshot.primaryDeviceName,
                       let devPct = snapshot.primaryDevicePercent {
                        Spacer()
                        Label("\(devName): \(devPct)%", systemImage: "iphone")
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AmpifyTheme.surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
        )
    }
}

struct DiagnosticsSheetView: View {
    @ObservedObject var store: BatteryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ampify Hardware & Device Diagnostics")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.diagnosticsText, forType: .string)
                }
                .controlSize(.small)

                Button("Done") {
                    dismiss()
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }

            ScrollView {
                Text(store.diagnosticsText)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AmpifyTheme.subtleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
            )
        }
        .padding(18)
        .frame(width: 560, height: 420)
        .background(AmpifyTheme.windowBackground)
    }
}
