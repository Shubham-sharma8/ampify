import SwiftUI
import AppKit
#if canImport(BatteryCore)
import BatteryCore
#endif

/// Calm, native macOS System UI theme modeled directly on Cogify Helium.
/// Uses standard system fonts with .regular and .medium weights only — no neon colors, no heavy/bold text.
public enum AmpifyTheme {
    public static let windowBackground = Color(nsColor: .windowBackgroundColor)
    public static let surfaceBackground = Color(nsColor: .controlBackgroundColor)
    public static let subtleFill = Color.primary.opacity(0.04)
    public static let hairBorder = Color.primary.opacity(0.08)

    // Calm semantic tones (standard macOS system palette, no neon)
    public static let accent = Color(nsColor: .controlAccentColor)
    public static let good = Color(nsColor: .systemGreen)
    public static let caution = Color(nsColor: .systemOrange)
    public static let critical = Color(nsColor: .systemRed)
    public static let neutral = Color(nsColor: .secondaryLabelColor)

    public static func toneColor(_ tone: StatusExplanation.Tone) -> Color {
        switch tone {
        case .good: return good
        case .neutral: return accent
        case .caution: return caution
        case .alert: return critical
        }
    }

    public static func thermalColor(_ band: ThermalBand) -> Color {
        switch band {
        case .cool, .normal: return good
        case .warm: return caution
        case .hot: return critical
        }
    }
}

public struct AmpifyCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AmpifyTheme.surfaceBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AmpifyTheme.hairBorder, lineWidth: 1)
            )
    }
}

public struct AmpifySectionHeader: View {
    public let title: String
    public var subtitle: String? = nil
    public var trailing: String? = nil

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

public struct AmpifyStatusPill: View {
    public let text: String
    public let color: Color

    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
        )
    }
}

public struct AmpifyMetricTile: View {
    public let label: String
    public let value: String
    public var caption: String? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
            if let caption {
                Text(caption)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
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
}

/// Clean horizontal battery gauge with the 80% limit line marker.
public struct BatteryGlyphView: View {
    public let percentage: Int
    public let limit: Int?
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public var width: CGFloat = 42
    public var height: CGFloat = 18

    private var fillColor: Color {
        if percentage <= 15 && !isPluggedIn {
            return AmpifyTheme.critical
        }
        if percentage <= 25 && !isPluggedIn {
            return AmpifyTheme.caution
        }
        if let limit, limit < 100, isPluggedIn, !isCharging, abs(percentage - limit) <= 2 {
            return AmpifyTheme.good
        }
        return Color.primary.opacity(0.75)
    }

    public var body: some View {
        HStack(spacing: 2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.2)
                    .frame(width: width, height: height)

                let innerWidth = max(0, width - 5)
                let fillWidth = innerWidth * CGFloat(min(100, max(0, percentage))) / 100.0

                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth, height: max(4, height - 5))
                    .padding(.leading, 2.5)

                if let limit, limit > 0 && limit < 100 {
                    let limitX = 2.5 + innerWidth * CGFloat(limit) / 100.0
                    Rectangle()
                        .fill(Color.primary.opacity(0.65))
                        .frame(width: 1.2, height: height - 2)
                        .offset(x: limitX)
                }
            }
            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .fill(Color.primary.opacity(0.35))
                .frame(width: 2.5, height: height * 0.42)
        }
    }
}
