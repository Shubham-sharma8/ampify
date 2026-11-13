import Foundation
import AppKit
import SwiftUI
#if canImport(BatteryCore)
import BatteryCore
#endif

@MainActor
public enum ReportPDFGenerator {
    public static func exportHealthReport(store: BatteryStore) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export 1-Page Battery Health Report"
        savePanel.nameFieldStringValue = "Ampify-Battery-Health-Report.pdf"
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let targetURL = savePanel.url else {
            return
        }

        let reportView = PrintableHealthReportView(
            reading: store.reading,
            projection: store.healthProjection,
            weekSummary: store.weekSummary,
            serviceEstimate: store.serviceEstimate,
            modelIdentifier: IOKitBatterySource.currentHardwareModelIdentifier()
        )
        .frame(width: 595, height: 842) // A4 at 72 DPI
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: reportView)
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)

        guard let consumer = CGDataConsumer(url: targetURL as CFURL),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return
        }

        renderer.render { size, renderInContext in
            var pageBox = CGRect(origin: .zero, size: size)
            pdfContext.beginPage(mediaBox: &pageBox)
            renderInContext(pdfContext)
            pdfContext.endPage()
            pdfContext.closePDF()
        }

        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }
}

private struct PrintableHealthReportView: View {
    let reading: BatteryReading
    let projection: HealthProjection
    let weekSummary: WeekSummary
    let serviceEstimate: BatteryServiceEstimate
    let modelIdentifier: String

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ampify Battery Health Report")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                    Text("Model: \(modelIdentifier) · Generated \(formattedDate)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text("Health \(reading.healthPercent)%")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    )
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Capacity & Cycle Summary")
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 12) {
                    summaryBox(title: "Full Charge Capacity", value: "\(reading.nominalCapacitymAh) mAh", sub: "Design: \(reading.designCapacitymAh) mAh")
                    summaryBox(title: "Health Percentage", value: "\(reading.healthPercent)%", sub: "Service line: 80%")
                    summaryBox(title: "Cycle Count", value: "\(reading.cycleCount)", sub: "Rated for \(reading.designCycleCount) cycles")
                    summaryBox(title: "Temperature", value: String(format: "%.1f °C", reading.temperatureCelsius), sub: reading.thermalBand.label)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("2. Longevity Projection & 80% Service Threshold")
                    .font(.system(size: 13, weight: .medium))
                VStack(alignment: .leading, spacing: 6) {
                    Text(projection.headline)
                        .font(.system(size: 12, weight: .medium))
                    Text(projection.detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(String(format: "Estimated annual capacity loss: %.1f%% per year", projection.dropPerYearPercent))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("3. Charging Habits (Last 7 Days)")
                    .font(.system(size: 13, weight: .medium))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Habit Rating: \(weekSummary.grade.rawValue)")
                        .font(.system(size: 12, weight: .medium))
                    Text(weekSummary.plainSummary)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("Configured Charge Limit: \(reading.activeChargeLimit.map { "\($0)% Active" } ?? "Off (100%)")")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("4. Apple Out-of-Warranty Battery Service Estimate")
                    .font(.system(size: 13, weight: .medium))
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(serviceEstimate.formattedPrice) (\(serviceEstimate.regionCode) Apple Store pricing as of \(serviceEstimate.asOfDate))")
                        .font(.system(size: 12, weight: .medium))
                    Text("Apple recommends battery service once maximum capacity drops below 80% of its original design capacity. If covered by AppleCare+, battery replacement at or below 79% is included at no additional charge.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
            }

            Spacer()

            Divider()
            HStack {
                Text("Generated locally on your Mac by Ampify — no telemetry or network requests.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Page 1 of 1")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(36)
        .background(Color.white)
    }

    private func summaryBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
            Text(sub)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}
