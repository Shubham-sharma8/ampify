import SwiftUI
import AppKit
import AppIntents
#if canImport(BatteryCore)
import BatteryCore
#endif

// MARK: - Shortcuts & AppIntents

public struct SetChargeLimitIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set 80% Charge Limit"
    public static var description = IntentDescription("Turns Ampify's 80% charge limit on or off.")

    @Parameter(title: "Hold at 80%")
    public var enabled: Bool

    public init() {
        self.enabled = true
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        BatteryStore.shared.setChargeLimitEnabled(enabled)
        let msg = enabled
            ? "Ampify is now holding your Mac battery at 80%."
            : "Ampify charge limit turned off (charging to 100% allowed)."
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }
}

public struct ChargeToFullOnceIntent: AppIntent {
    public static var title: LocalizedStringResource = "Charge to 100% Once"
    public static var description = IntentDescription("Charges your Mac to 100% once and automatically restores the 80% limit when unplugged.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        BatteryStore.shared.startFullChargeOnce(restoreOnUnplug: true, restoreWhenFull: false, hours: 12)
        return .result(dialog: "Charging to 100% once. Your 80% charge limit will return when you unplug.")
    }
}

public struct GetBatteryHealthIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Battery Health Summary"
    public static var description = IntentDescription("Returns your Mac's current battery percentage, health capacity, cycle count, and charge-limit state.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = BatteryStore.shared
        store.refreshLiveState()
        let r = store.reading
        let summary = "\(r.percentage)% (\(store.statusExplanation.badgeText)) · Health \(r.healthPercent)% (\(r.nominalCapacitymAh)/\(r.designCapacitymAh) mAh, \(r.cycleCount) cycles)"
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

public struct AmpifyShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetChargeLimitIntent(),
            phrases: ["Set charge limit in \(.applicationName)"],
            shortTitle: "Set 80% Limit",
            systemImageName: "battery.75percent"
        )
        AppShortcut(
            intent: ChargeToFullOnceIntent(),
            phrases: ["Charge to 100% once in \(.applicationName)"],
            shortTitle: "Charge to 100% Once",
            systemImageName: "battery.100percent.bolt"
        )
        AppShortcut(
            intent: GetBatteryHealthIntent(),
            phrases: ["Check battery health in \(.applicationName)"],
            shortTitle: "Battery Health",
            systemImageName: "heart"
        )
    }
}

// MARK: - Main Application

@main
public struct AmpifyApp: App {
    @StateObject private var store = BatteryStore.shared
    @Environment(\.openWindow) private var openWindow

    public init() {
        if CommandLine.arguments.contains("--render-marketing") {
            let outPath = CommandLine.arguments.drop(while: { $0 != "--render-marketing" }).dropFirst().first
                ?? "/Users/shubhamsharma/Downloads/Ampify/marketing/screenshots"
            MainActor.assumeIsolated {
                MarketingShowcaseRenderer.renderAll(to: URL(fileURLWithPath: outPath))
            }
            exit(0)
        }
    }

    public var body: some Scene {
        Window("Ampify", id: "dashboard") {
            DashboardView(store: store)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 920, height: 620)

        MenuBarExtra {
            PanelView(store: store) { section in
                store.selectedSection = section
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarSymbolName)
                if !store.menuBarText.isEmpty {
                    Text(store.menuBarText)
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbolName: String {
        if store.reading.isCharging {
            return "battery.100percent.bolt"
        }
        let pct = store.reading.percentage
        if pct >= 88 { return "battery.100percent" }
        if pct >= 63 { return "battery.75percent" }
        if pct >= 38 { return "battery.50percent" }
        if pct >= 15 { return "battery.25percent" }
        return "battery.0percent"
    }
}

// MARK: - Marketing Screenshots Renderer (2560x1720 Retina in Cogify Helium Style)

@MainActor
public enum MarketingShowcaseRenderer {
    public static func renderAll(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let store = BatteryStore.shared
        store.hasCompletedOnboarding = true
        store.showOnboardingSheet = false

        // Populate rich, realistic live telemetry for marketing screenshots
        store.reading = BatteryReading(
            timestamp: Date(),
            percentage: 80,
            isPluggedIn: true,
            isCharging: false,
            isFullyCharged: false,
            activeChargeLimit: 80,
            storedChargeLimit: 80,
            isLimitSupported: true,
            healthPercent: 99,
            nominalCapacitymAh: 4460,
            rawMaxCapacitymAh: 4455,
            designCapacitymAh: 4500,
            currentCapacitymAh: 3568,
            cycleCount: 74,
            designCycleCount: 1000,
            temperatureCelsius: 28.6,
            voltageVolts: 12.18,
            amperageAmps: 0.0,
            batteryWatts: 0.0,
            systemPowerInWatts: 14.2,
            systemLoadWatts: 14.2,
            adapterWatts: 67
        )
        store.limitEnabled = true
        store.fullChargeSession = nil
        store.statusExplanation = StatusExplanation.explain(
            reading: store.reading,
            limitStatus: .holding(limit: 80),
            fullChargeSession: nil,
            recalibrating: false
        )
        store.powerFlow = PowerFlowSnapshot.compute(from: store.reading, biggestSeenWatts: 96)

        store.appleDevices = [
            ConnectedAppleDevice(
                udid: "00008120-000610812EE3601E",
                name: "Shubham’s iPhone 15 Plus",
                productType: "iPhone15,5",
                kind: .iPhone,
                batteryPercent: 60,
                isCharging: false,
                cycleCount: 118,
                healthPercent: 97
            ),
            ConnectedAppleDevice(
                udid: "00008112-001420911AA2401B",
                name: "Shubham’s iPad Pro",
                productType: "iPad14,5",
                marketingModel: "iPad Pro 12.9-inch (M2)",
                kind: .iPad,
                batteryPercent: 57,
                isCharging: true,
                cycleCount: 64,
                healthPercent: 98
            ),
            ConnectedAppleDevice(
                udid: "00008006-001B75CE2EB8C02E",
                name: "Shubham’s Apple Watch",
                productType: "Watch6,18",
                kind: .appleWatch,
                batteryPercent: 89,
                isCharging: false
            )
        ]

        store.bluetoothAccessories = [
            BluetoothAccessoryBattery(
                id: "bt-airpods",
                name: "Shubham’s AirPods Pro",
                kind: .earbuds,
                isConnected: true,
                primaryPercent: 93,
                leftPercent: 93,
                rightPercent: 93,
                casePercent: 96
            ),
            BluetoothAccessoryBattery(
                id: "bt-pencil",
                name: "Apple Pencil Pro",
                kind: .applePencil,
                isConnected: true,
                primaryPercent: 100
            ),
            BluetoothAccessoryBattery(
                id: "bt-atv",
                name: "Apple TV Siri Remote",
                kind: .appleTVRemote,
                isConnected: true,
                primaryPercent: 84
            ),
            BluetoothAccessoryBattery(
                id: "bt-mouse",
                name: "Magic Mouse",
                kind: .mouse,
                isConnected: true,
                primaryPercent: 95
            )
        ]

        store.topEnergyApps = [
            AppEnergyEntry(pid: -10, bundleIdentifier: "com.apple.Safari", name: "Safari", watts: 0.2, cpuPercent: 1.4, extraMinutesIfQuit: nil, kind: .application),
            AppEnergyEntry(pid: -11, bundleIdentifier: "com.apple.Terminal", name: "Terminal", watts: 0.1, cpuPercent: 0.6, extraMinutesIfQuit: nil, kind: .application),
            AppEnergyEntry(pid: -1, bundleIdentifier: "com.apple.finder", name: "macOS itself", watts: 0.1, cpuPercent: 0.8, extraMinutesIfQuit: nil, kind: .macOSItself),
            AppEnergyEntry(pid: -2, bundleIdentifier: nil, name: "Everything else", watts: 0.1, cpuPercent: 0.5, extraMinutesIfQuit: nil, kind: .everythingElse)
        ]

        store.upcomingTrips = [
            CalendarTripMatch(
                title: "Flight to San Francisco (SFO)",
                startDate: Date().addingTimeInterval(18 * 3600),
                isAllDay: false,
                matchedKeyword: "flight",
                topUpScheduledAt: Date().addingTimeInterval(10 * 3600)
            )
        ]
        store.syncWidgetSnapshot(persistToDisk: false)

        // 1. Hero Popover + Now Dashboard
        store.selectedSection = .now
        saveMarketingCanvas(
            badge: "AMPIFY FOR MACOS · COGIFY HELIUM SYSTEM UI",
            title: "Hold at 80%. See every Apple device battery at a glance.",
            subtitle: "Native PowerUI charge limiting, liquid-wave Apple ecosystem batteries, and live per-app wattage in a calm macOS interface.",
            filename: "01-ampify-hero-popover-and-liquid-devices.png",
            directory: directory
        ) {
            HStack(alignment: .center, spacing: 24) {
                macWindowChrome(title: "Menu Bar Popover", width: 376) {
                    PanelView(store: store, openDashboard: { _ in })
                }
                macWindowChrome(title: "Ampify — Now", width: 790) {
                    DashboardView(store: store)
                        .frame(width: 790, height: 560)
                }
            }
        }

        // 2. Apple Devices Liquid Strip & Battery Health Close-Up
        saveMarketingCanvas(
            badge: "LIQUID-WAVE APPLE ECOSYSTEM BATTERIES",
            title: "iPhone, iPad, Watch, AirPods, Pencil & Apple TV — over Wi-Fi & Bluetooth.",
            subtitle: "Liquid-wave silhouettes fill proportionally to each device's charge level, with charging bolts, bubbles, and Mac battery health.",
            filename: "02-ampify-apple-devices-liquid-strip-and-health.png",
            directory: directory
        ) {
            HStack(alignment: .center, spacing: 28) {
                VStack(spacing: 14) {
                    AppleDevicesLiquidStripCard(
                        slots: Array(store.ecosystemDeviceSlots.prefix(4)),
                        showLabels: true,
                        compact: false
                    )
                    BatteryHealthBannerCard(
                        healthPercent: 91,
                        subtitle: "Normal wear, nothing to do.",
                        compact: false
                    )
                }
                .padding(22)
                .frame(width: 490)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 12)

                VStack(spacing: 14) {
                    AppleDevicesLiquidStripCard(
                        slots: Array(store.ecosystemDeviceSlots.dropFirst(4).prefix(4)),
                        showLabels: true,
                        compact: false
                    )
                    BatteryHealthBannerCard(
                        healthPercent: 99,
                        subtitle: "74 cycles · Holding at 80% on wall power.",
                        compact: false
                    )
                }
                .padding(22)
                .frame(width: 490)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 12)
            }
        }

        // 3. What's Using Power Live Wattage Close-Up + Energy Tab
        store.selectedSection = .energy
        saveMarketingCanvas(
            badge: "REAL-TIME HARDWARE ENERGY TELEMETRY",
            title: "What's using power — measured in real Watts, not vague numbers.",
            subtitle: "See exact wattage going to your apps, macOS itself, and background tasks right now, with one-click actions to quit heavy apps.",
            filename: "03-ampify-whats-using-power-live-watts.png",
            directory: directory
        ) {
            HStack(alignment: .center, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    WhatsUsingPowerSectionView(
                        entries: store.topEnergyApps,
                        compact: false,
                        allowAppActions: false
                    )
                }
                .padding(22)
                .frame(width: 430)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 12)

                macWindowChrome(title: "Ampify — Energy & Sleep Drain", width: 730) {
                    DashboardView(store: store)
                        .frame(width: 730, height: 540)
                }
            }
        }

        // 4. Desktop & Notification Center Widgets Showcase
        store.selectedSection = .widgets
        saveMarketingCanvas(
            badge: "5 NATIVE MACOS SONOMA, SEQUOIA & TAHOE WIDGETS",
            title: "Interactive Desktop Widgets for every Apple device you own.",
            subtitle: "Add the Apple Devices Liquid Strip, iPad & Pencil Ecosystem widget, What's Using Power widget, or 80% Hold widget to your Mac desktop.",
            filename: "04-ampify-desktop-widgets-showcase.png",
            directory: directory
        ) {
            macWindowChrome(title: "Ampify — macOS Desktop Widgets", width: 1040) {
                DashboardView(store: store)
                    .frame(width: 1040, height: 575)
            }
        }

        // 5. 80% Charge Limit & 3-Node Live Power Flow
        store.selectedSection = .now
        saveMarketingCanvas(
            badge: "NATIVE POWERUI CHARGE LIMIT & POWER FLOW",
            title: "Bypass battery cycles while plugged in at your desk.",
            subtitle: "Holds your Mac at 80% without any third-party root daemon, tracks your largest charger, and explains macOS calibration slips.",
            filename: "05-ampify-80-percent-hold-and-power-flow.png",
            directory: directory
        ) {
            macWindowChrome(title: "Ampify — Live Power Flow & 80% Charge Limit", width: 1040) {
                DashboardView(store: store)
                    .frame(width: 1040, height: 575)
            }
        }

        // 6. Battery Health Longevity & Official Apple Service Price Lookup
        store.selectedSection = .health
        saveMarketingCanvas(
            badge: "BATTERY LONGEVITY & SERVICE THRESHOLD",
            title: "Track capacity fade against Apple's 80% service line.",
            subtitle: "Includes 1-page printable PDF health reports and offline Apple Store out-of-warranty battery replacement pricing across 6 regions.",
            filename: "06-ampify-longevity-and-service-price.png",
            directory: directory
        ) {
            macWindowChrome(title: "Ampify — Health & Apple Service Estimate", width: 1040) {
                DashboardView(store: store)
                    .frame(width: 1040, height: 575)
            }
        }

        // 7. Smart Trip Calendar Top-Up & Learned Weekday Departure
        store.selectedSection = .habits
        saveMarketingCanvas(
            badge: "CALENDAR TRIP TOP-UP & LEARNED DEPARTURE",
            title: "80% at your desk. 100% automatically before you travel.",
            subtitle: "Scans Calendar for upcoming flights or trips, learns your weekday unplug routine, and restores 80% hold as soon as you unplug.",
            filename: "07-ampify-smart-trip-and-departure-topup.png",
            directory: directory
        ) {
            macWindowChrome(title: "Ampify — Habits & Smart Top-Up", width: 1040) {
                DashboardView(store: store)
                    .frame(width: 1040, height: 575)
            }
        }

        // 8. Full Apple Ecosystem Devices Dashboard
        store.selectedSection = .devices
        saveMarketingCanvas(
            badge: "WIRELESS COREDEVICE & BLUETOOTH TELEMETRY",
            title: "Automatic Wi-Fi discovery for iPhone, iPad & Apple Watch.",
            subtitle: "Wakes the wireless CoreDevice tunnel in the background to read battery %, charging state, cycle count, and AirPods L/R/Case levels.",
            filename: "08-ampify-macos-ecosystem-devices-dashboard.png",
            directory: directory
        ) {
            macWindowChrome(title: "Ampify — Connected Apple Devices", width: 1040) {
                DashboardView(store: store)
                    .frame(width: 1040, height: 575)
            }
        }
    }

    private static func saveMarketingCanvas<Content: View>(
        badge: String,
        title: String,
        subtitle: String,
        filename: String,
        directory: URL,
        @ViewBuilder content: () -> Content
    ) {
        let view = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.11),
                    Color(red: 0.11, green: 0.12, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.38, green: 0.80, blue: 0.60).opacity(0.14),
                    Color.clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 560
            )

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.62, green: 0.92, blue: 0.76))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.38, green: 0.80, blue: 0.60).opacity(0.14))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color(red: 0.55, green: 0.90, blue: 0.72).opacity(0.28), lineWidth: 1)
                        )

                    Text(title)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 860)
                }
                .padding(.top, 28)

                content()
                    .environment(\.colorScheme, .dark)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 36)
        }
        .frame(width: 1280, height: 860)
        .environment(\.colorScheme, .dark)

        let canvasWidth: CGFloat = 1280
        let canvasHeight: CGFloat = 860
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        hostingView.appearance = NSAppearance(named: .darkAqua)

        let offscreenWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: canvasWidth, height: canvasHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        offscreenWindow.appearance = NSAppearance(named: .darkAqua)
        offscreenWindow.contentView = hostingView
        offscreenWindow.orderBack(nil)
        hostingView.layoutSubtreeIfNeeded()
        offscreenWindow.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))
        hostingView.layoutSubtreeIfNeeded()

        let bounds = hostingView.bounds
        if let rep = hostingView.bitmapImageRepForCachingDisplay(in: bounds) {
            hostingView.cacheDisplay(in: bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                let outURL = directory.appendingPathComponent(filename)
                try? png.write(to: outURL)
                print("Rendered marketing screenshot: \(outURL.path)")
            }
        }
        offscreenWindow.orderOut(nil)
    }

    private static func macWindowChrome<Content: View>(
        title: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 11, height: 11)
                Spacer()
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 45, height: 11)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            content()
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.38), radius: 28, x: 0, y: 14)
    }
}
