import SwiftUI
import AppKit
#if canImport(BatteryCore)
import BatteryCore
#endif

public struct OnboardingView: View {
    @ObservedObject public var store: BatteryStore
    @Environment(\.dismiss) private var dismiss

    public init(store: BatteryStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if let url = AmpifyResourceBundle.url(forResource: "AmpifyIcon-Canva", withExtension: "png"),
                   let img = NSImage(contentsOf: url) {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Ampify")
                        .font(.system(size: 17, weight: .medium))
                    Text("Battery care that speaks plain English — with calm System UI.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                onboardingRow(
                    symbol: "battery.75percent",
                    title: "Hold at 80% Without a Root Helper",
                    detail: "Ampify uses macOS's built-in PowerUI charge-limit interface to hold your battery at 80% when plugged in at a desk, running your Mac directly off the power adapter."
                )
                onboardingRow(
                    symbol: "calendar.badge.clock",
                    title: "Automatic 100% Top-Up Before Trips & Departures",
                    detail: "Heading to the airport or leaving at your usual weekday time? Ampify charges to 100% beforehand and restores the 80% limit automatically when you unplug."
                )
                onboardingRow(
                    symbol: "text.bubble",
                    title: "Simple or Technical — Your Choice",
                    detail: "Read clear, everyday sentences in Simple mode, or switch to Technical mode anytime for live Watts, Voltage, Amperage, mAh, and powerd calibration telemetry."
                )
            }

            AmpifyCard(padding: 12) {
                HStack {
                    Text("Turn on the 80% Charge Limit now")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.limitEnabled },
                        set: { store.setChargeLimitEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            HStack {
                Spacer()
                Button("Get Started") {
                    store.hasCompletedOnboarding = true
                    store.showOnboardingSheet = false
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(AmpifyTheme.windowBackground)
    }

    private func onboardingRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(detail)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
