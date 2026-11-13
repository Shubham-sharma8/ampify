// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ampify",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BatteryCore", targets: ["BatteryCore"]),
        .executable(name: "Ampify", targets: ["Ampify"]),
        .executable(name: "AmpifyWidget", targets: ["AmpifyWidget"])
    ],
    targets: [
        .target(
            name: "AmpifyBridge",
            path: "Sources/AmpifyBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit")
            ]
        ),
        .target(
            name: "BatteryCore",
            dependencies: ["AmpifyBridge"],
            path: "Sources/BatteryCore",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .executableTarget(
            name: "Ampify",
            dependencies: ["BatteryCore", "AmpifyBridge"],
            path: "Sources/Ampify",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("AppIntents"),
                .linkedFramework("PDFKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .executableTarget(
            name: "AmpifyWidget",
            dependencies: ["BatteryCore", "AmpifyBridge"],
            path: "Sources/AmpifyWidget",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit"),
                .linkedFramework("AppIntents"),
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        )
    ]
)
