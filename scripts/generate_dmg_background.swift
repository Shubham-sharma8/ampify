#!/usr/bin/env swift

import SwiftUI
import AppKit
import Foundation

let rootDir = URL(fileURLWithPath: "/Users/shubhamsharma/Downloads/Ampify")
let bgOutputURL = rootDir.appendingPathComponent("00-dmg-background.png")
let marketingDir = rootDir.appendingPathComponent("marketing/screenshots", isDirectory: true)
try? FileManager.default.createDirectory(at: marketingDir, withIntermediateDirectories: true)
let previewOutputURL = marketingDir.appendingPathComponent("09-ampify-dmg-installer-preview.png")

struct DMGBackgroundCanvasView: View {
    let includeMockIcons: Bool

    var body: some View {
        ZStack {
            // Warm stone background matching Cogify Helium / Wifyy
            Color(red: 0.965, green: 0.961, blue: 0.953)

            RadialGradient(
                colors: [
                    Color(red: 0.85, green: 0.95, blue: 0.90).opacity(0.55),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 260
            )

            // Top Headline: "drag [ Ampify ] into applications, then open it."
            VStack {
                HStack(spacing: 6) {
                    Text("drag")
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundStyle(Color(red: 0.16, green: 0.16, blue: 0.18))
                    Text("Ampify")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.08, green: 0.14, blue: 0.11))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(red: 0.84, green: 0.94, blue: 0.88))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(red: 0.68, green: 0.85, blue: 0.75), lineWidth: 1)
                        )
                    Text("into applications, then open it.")
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundStyle(Color(red: 0.16, green: 0.16, blue: 0.18))
                }
                .padding(.top, 38)

                Spacer()

                // Bottom Subtitle: "smart 80% charge limit & apple device batteries. [ local ] on your mac."
                HStack(spacing: 5) {
                    Text("smart 80% charge limit & apple device batteries.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.38, green: 0.38, blue: 0.40))
                    Text("local")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.20))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(red: 0.90, green: 0.90, blue: 0.89))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color(red: 0.81, green: 0.81, blue: 0.79), lineWidth: 1)
                        )
                    Text("on your mac.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.38, green: 0.38, blue: 0.40))
                }
                .padding(.bottom, 34)
            }

            // Drop slot cards at Finder coordinates (170, 195) and (430, 195)
            dropSlotCard
                .position(x: 170, y: 195)

            dropSlotCard
                .position(x: 430, y: 195)

            // Arrow between (170, 195) and (430, 195)
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(red: 0.30, green: 0.32, blue: 0.35).opacity(0.55))
                .position(x: 300, y: 195)

            if includeMockIcons {
                mockIconColumn(isApp: true)
                    .position(x: 170, y: 195)

                mockIconColumn(isApp: false)
                    .position(x: 430, y: 195)
            }
        }
        .frame(width: 600, height: 400)
    }

    private var dropSlotCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.68))
            .frame(width: 132, height: 132)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func mockIconColumn(isApp: Bool) -> some View {
        VStack(spacing: 8) {
            if isApp,
               let nsImg = NSImage(contentsOf: rootDir.appendingPathComponent("Sources/Ampify/Resources/AmpifyIcon-Canva.png")) {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: "/Applications"))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 78, height: 78)
            }
            Text(isApp ? "Ampify.app" : "Applications")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.17))
        }
    }
}

@MainActor
func renderDMGImages() throws {
    for (includeIcons, outURL) in [(false, bgOutputURL), (true, previewOutputURL)] {
        let renderer = ImageRenderer(content: DMGBackgroundCanvasView(includeMockIcons: includeIcons))
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { continue }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: 600, height: 400) // 144 DPI @2x
        if let png = rep.representation(using: .png, properties: [:]) {
            try png.write(to: outURL)
            print("Saved \(outURL.path)")
        }
    }
}

try MainActor.assumeIsolated {
    try renderDMGImages()
}
