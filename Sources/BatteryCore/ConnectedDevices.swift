import Foundation
import IOKit
#if canImport(AmpifyBridge)
import AmpifyBridge
#endif

// MARK: - iPhone, iPad, and Apple Watch over Wi-Fi / USB (MobileDeviceBridge + CoreDevice Wake)

public struct ConnectedAppleDevice: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case iPhone
        case iPad
        case appleWatch

        public var sfSymbol: String {
            switch self {
            case .iPhone: return "iphone"
            case .iPad: return "ipad"
            case .appleWatch: return "applewatch"
            }
        }
    }

    public var id: String { udid }
    public var udid: String
    public var name: String
    public var productType: String
    public var marketingModel: String
    public var kind: Kind
    public var batteryPercent: Int
    public var isCharging: Bool
    public var cycleCount: Int?
    public var healthPercent: Int?
    public var lastSeen: Date
    public var isBluetoothNearbyOnly: Bool

    public var seenAgoText: String {
        let seconds = Int(Date().timeIntervalSince(lastSeen))
        if seconds < 90 { return "Just now" }
        let mins = seconds / 60
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        return "\(hours)h ago"
    }

    public init(
        udid: String,
        name: String,
        productType: String,
        marketingModel: String? = nil,
        kind: Kind,
        batteryPercent: Int,
        isCharging: Bool,
        cycleCount: Int? = nil,
        healthPercent: Int? = nil,
        lastSeen: Date = Date(),
        isBluetoothNearbyOnly: Bool = false
    ) {
        self.udid = udid
        self.name = name
        self.productType = productType
        self.marketingModel = marketingModel ?? Self.friendlyModelName(for: productType, kind: kind)
        self.kind = kind
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.cycleCount = cycleCount
        self.healthPercent = healthPercent
        self.lastSeen = lastSeen
        self.isBluetoothNearbyOnly = isBluetoothNearbyOnly
    }

    public static func friendlyModelName(for productType: String, kind: Kind) -> String {
        let map: [String: String] = [
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            "Watch5,11": "Apple Watch SE (40mm)",
            "Watch5,12": "Apple Watch SE (44mm)",
            "Watch6,14": "Apple Watch Series 8 (41mm)",
            "Watch6,15": "Apple Watch Series 8 (45mm)",
            "Watch6,18": "Apple Watch Ultra",
            "Watch7,1": "Apple Watch Series 9 (41mm)",
            "Watch7,2": "Apple Watch Series 9 (45mm)",
            "Watch7,5": "Apple Watch Ultra 2"
        ]
        if let known = map[productType] {
            return known
        }
        return productType
    }
}

public enum MobileDeviceScanner {
    public static func isAvailable() -> Bool {
        MobileDeviceBridge.isAvailable()
    }

    /// Wakes the iOS 17+ CoreDevice local-network tunnel so MobileDevice.framework can immediately query Wi-Fi devices.
    private static func wakeCoreDeviceWiFiTunnels() {
        let devicectlPath = "/Library/Developer/PrivateFrameworks/CoreDevice.framework/Versions/A/Resources/bin/devicectl"
        guard FileManager.default.isExecutableFile(atPath: devicectlPath) else { return }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ampify-devicectl-\(ProcessInfo.processInfo.processIdentifier).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let listProc = Process()
        listProc.executableURL = URL(fileURLWithPath: devicectlPath)
        listProc.arguments = ["list", "devices", "--timeout", "6", "--json-output", tempURL.path]
        listProc.standardOutput = FileHandle.nullDevice
        listProc.standardError = FileHandle.nullDevice
        do {
            try listProc.run()
            listProc.waitUntilExit()
        } catch {
            return
        }

        guard let data = try? Data(contentsOf: tempURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let devices = result["devices"] as? [[String: Any]] else {
            return
        }

        for dev in devices {
            let conn = (dev["connectionProperties"] as? [String: Any]) ?? ((dev["properties"] as? [String: Any])?["connection"] as? [String: Any])
            let pairing = conn?["pairingState"] as? String
            let tunnelState = (conn?["tunnelState"] as? String) ?? (conn?["state"] as? String)
            let hw = (dev["hardwareProperties"] as? [String: Any]) ?? ((dev["properties"] as? [String: Any])?["hardware"] as? [String: Any])
            let udid = (hw?["udid"] as? String) ?? (dev["identifier"] as? String)

            if pairing == "paired", let udid, tunnelState != "connected" {
                let wakeProc = Process()
                wakeProc.executableURL = URL(fileURLWithPath: devicectlPath)
                wakeProc.arguments = ["device", "info", "lockState", "--device", udid, "--timeout", "8"]
                wakeProc.standardOutput = FileHandle.nullDevice
                wakeProc.standardError = FileHandle.nullDevice
                try? wakeProc.run()
                wakeProc.waitUntilExit()
            }
        }
    }

    private static func extractWatchValue(_ raw: Any?, key: String) -> Any? {
        guard let dict = raw as? [String: Any] else { return raw }
        if let inner = dict["RetrievedValueDictionary"] as? [String: Any] {
            return inner[key]
        }
        return dict[key]
    }

    public static func scanPairedDevices(timeout: TimeInterval = 3.5) -> [ConnectedAppleDevice] {
        guard MobileDeviceBridge.isAvailable() else { return [] }

        // Ensure iOS 17+ / iOS 27 CoreDevice wireless tunnel is awake before subscribing
        wakeCoreDeviceWiFiTunnels()
        let rawList = MobileDeviceBridge.readDevices(withTimeout: timeout)

        var discovered: [ConnectedAppleDevice] = []
        let now = Date()

        for item in rawList {
            guard let udid = item["UDID"] as? String else { continue }
            let name = (item["DeviceName"] as? String) ?? "iPhone"
            let productType = (item["ProductType"] as? String) ?? "iPhone"
            let kind: ConnectedAppleDevice.Kind = productType.lowercased().contains("ipad") ? .iPad : .iPhone

            var pct = 0
            var charging = false
            if let batt = item["BatteryDomain"] as? [String: Any] {
                pct = (batt["BatteryCurrentCapacity"] as? Int) ?? 0
                charging = ((batt["BatteryIsCharging"] as? Int) ?? 0) != 0 || ((batt["BatteryIsCharging"] as? Bool) ?? false)
            }

            var cycles: Int? = nil
            var health: Int? = nil

            // Check IORegistry AppleSmartBattery reply
            if let diag = item["DiagnosticsReply"] as? [String: Any],
               let ioReg = (diag["Diagnostics"] as? [String: Any])?["IORegistry"] as? [String: Any] {
                if let c = ioReg["CycleCount"] as? Int {
                    cycles = c
                }
                let nominal = (ioReg["NominalChargeCapacity"] as? Int) ?? (ioReg["AppleRawMaxCapacity"] as? Int)
                let design = ioReg["DesignCapacity"] as? Int
                if let nominal, let design, design > 0 {
                    let ratio = (Double(nominal) / Double(design)) * 100.0
                    health = min(100, max(50, Int(ratio.rounded())))
                }
            }

            // Check GasGauge reply
            if let gasRoot = item["GasGaugeReply"] as? [String: Any],
               let gasGauge = (gasRoot["Diagnostics"] as? [String: Any])?["GasGauge"] as? [String: Any] {
                if cycles == nil, let c = gasGauge["CycleCount"] as? Int {
                    cycles = c
                }
                if health == nil, let fullCap = gasGauge["FullChargeCapacity"] as? Int {
                    if (50...110).contains(fullCap) {
                        health = min(100, fullCap)
                    } else if let designCap = gasGauge["DesignCapacity"] as? Int, designCap > 0 {
                        health = min(100, max(50, Int((Double(fullCap) / Double(designCap) * 100.0).rounded())))
                    }
                }
            }

            if pct > 0 {
                discovered.append(
                    ConnectedAppleDevice(
                        udid: udid,
                        name: name,
                        productType: productType,
                        kind: kind,
                        batteryPercent: pct,
                        isCharging: charging,
                        cycleCount: cycles,
                        healthPercent: health,
                        lastSeen: now
                    )
                )
            }

            // Extract paired Apple Watches from com.apple.companion_proxy
            if let watches = item["Watches"] as? [[String: Any]] {
                for w in watches {
                    guard let wUDID = w["UDID"] as? String else { continue }
                    let wName = (extractWatchValue(w["DeviceName"], key: "DeviceName") as? String) ?? "Apple Watch"
                    let wProd = (extractWatchValue(w["ProductType"], key: "ProductType") as? String) ?? "Watch"
                    let wPctVal = extractWatchValue(w["BatteryCurrentCapacity"], key: "BatteryCurrentCapacity")
                    let wChgVal = extractWatchValue(w["BatteryIsCharging"], key: "BatteryIsCharging")

                    let wPct: Int = (wPctVal as? Int) ?? (wPctVal as? NSNumber)?.intValue ?? 0
                    let wCharging: Bool = ((wChgVal as? Int) ?? (wChgVal as? NSNumber)?.intValue ?? 0) != 0

                    if wPct > 0 {
                        discovered.append(
                            ConnectedAppleDevice(
                                udid: wUDID,
                                name: wName,
                                productType: wProd,
                                kind: .appleWatch,
                                batteryPercent: wPct,
                                isCharging: wCharging,
                                cycleCount: nil,
                                healthPercent: nil,
                                lastSeen: now
                            )
                        )
                    }
                }
            }
        }

        return discovered
    }
}

// MARK: - Bluetooth & Apple Ecosystem Accessories (AirPods, Apple Pencil, Apple TV Remote, Keyboard, Mouse, Trackpad)

public struct BluetoothAccessoryBattery: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case headphones
        case earbuds
        case applePencil
        case appleTVRemote
        case keyboard
        case mouse
        case trackpad
        case other

        public var sfSymbol: String {
            switch self {
            case .headphones: return "headphones"
            case .earbuds: return "airpodspro"
            case .applePencil: return "applepencil.gen2"
            case .appleTVRemote: return "appletvremote.gen4"
            case .keyboard: return "keyboard"
            case .mouse: return "magicmouse"
            case .trackpad: return "rectangle.and.hand.point.up.left"
            case .other: return "dot.radiowaves.left.and.right"
            }
        }
    }

    public var id: String
    public var name: String
    public var kind: Kind
    public var isConnected: Bool
    public var primaryPercent: Int?
    public var leftPercent: Int?
    public var rightPercent: Int?
    public var casePercent: Int?

    public var detailSummary: String {
        var parts: [String] = []
        if let l = leftPercent { parts.append("L \(l)%") }
        if let r = rightPercent { parts.append("R \(r)%") }
        if let c = casePercent { parts.append("Case \(c)%") }
        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }
        if let primaryPercent {
            return isConnected ? "Connected · \(primaryPercent)%" : "\(primaryPercent)%"
        }
        return isConnected ? "Connected" : "Paired · In case or standby"
    }

    public init(
        id: String,
        name: String,
        kind: Kind,
        isConnected: Bool = true,
        primaryPercent: Int? = nil,
        leftPercent: Int? = nil,
        rightPercent: Int? = nil,
        casePercent: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isConnected = isConnected
        self.primaryPercent = primaryPercent
        self.leftPercent = leftPercent
        self.rightPercent = rightPercent
        self.casePercent = casePercent
    }
}

public enum BluetoothBatteryScanner {
    public struct ScanOutput: Sendable {
        public var accessories: [BluetoothAccessoryBattery]
        public var nearbyBluetoothAppleDeviceNames: [String]
    }

    public static func scanConnectedAccessories() -> [BluetoothAccessoryBattery] {
        scanAll().accessories
    }

    public static func scanAll() -> ScanOutput {
        var accessories: [BluetoothAccessoryBattery] = []
        var nearbyAppleNames: [String] = []
        var seenNames = Set<String>()

        // 1. Query IORegistry for AppleDeviceManagementHIDEventService (Magic Keyboard/Mouse/Trackpad)
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
                defer { IOObjectRelease(entry) }
                var propsRef: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let dict = propsRef?.takeRetainedValue() as? [String: Any] else {
                    continue
                }
                guard let name = dict["Product"] as? String, !name.isEmpty,
                      !name.lowercased().contains("internal"),
                      let pct = dict["BatteryPercent"] as? Int, pct > 0 else {
                    continue
                }
                guard !seenNames.contains(name) else { continue }
                seenNames.insert(name)

                let lowered = name.lowercased()
                let kind: BluetoothAccessoryBattery.Kind
                if lowered.contains("pencil") {
                    kind = .applePencil
                } else if lowered.contains("siri remote") || lowered.contains("apple tv") || lowered.contains("remote") {
                    kind = .appleTVRemote
                } else if lowered.contains("keyboard") {
                    kind = .keyboard
                } else if lowered.contains("mouse") {
                    kind = .mouse
                } else if lowered.contains("trackpad") {
                    kind = .trackpad
                } else {
                    kind = .other
                }

                accessories.append(
                    BluetoothAccessoryBattery(
                        id: (dict["DeviceAddress"] as? String) ?? name,
                        name: name,
                        kind: kind,
                        isConnected: true,
                        primaryPercent: pct
                    )
                )
            }
        }

        // 2. Query system_profiler SPBluetoothDataType -json for connected & paired accessories
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let btArray = root["SPBluetoothDataType"] as? [[String: Any]] {
                for section in btArray {
                    let connectedList = (section["device_connected"] as? [[String: [String: Any]]]) ?? []
                    let disconnectedList = (section["device_not_connected"] as? [[String: [String: Any]]]) ?? []

                    for (isConn, list) in [(true, connectedList), (false, disconnectedList)] {
                        for entry in list {
                            for (deviceName, info) in entry {
                                guard !seenNames.contains(deviceName) else { continue }
                                let lowered = deviceName.lowercased()

                                // Detect nearby iPhone/iPad/Watch in Bluetooth table
                                if lowered.contains("iphone") || lowered.contains("ipad") || lowered.contains("apple watch") || lowered.contains("apple\u{00a0}watch") {
                                    nearbyAppleNames.append(deviceName)
                                    continue
                                }

                                let mainPct = parsePercent(info["device_batteryLevelMain"] ?? info["device_batteryLevel"])
                                let leftPct = parsePercent(info["device_batteryLevelLeft"])
                                let rightPct = parsePercent(info["device_batteryLevelRight"])
                                let casePct = parsePercent(info["device_batteryLevelCase"])
                                let primary = mainPct ?? leftPct ?? rightPct ?? casePct

                                let minorType = (info["device_minorType"] as? String)?.lowercased() ?? ""
                                let kind: BluetoothAccessoryBattery.Kind
                                if lowered.contains("pencil") || minorType.contains("pencil") {
                                    kind = .applePencil
                                } else if lowered.contains("siri remote") || lowered.contains("apple tv") || minorType.contains("remote") {
                                    kind = .appleTVRemote
                                } else if leftPct != nil || rightPct != nil || lowered.contains("airpods") || lowered.contains("beats") {
                                    kind = .earbuds
                                } else if minorType.contains("headphones") || lowered.contains("headphones") || lowered.contains("airpods max") {
                                    kind = .headphones
                                } else if minorType.contains("keyboard") || lowered.contains("keyboard") {
                                    kind = .keyboard
                                } else if minorType.contains("mouse") || lowered.contains("mouse") || lowered.contains("lift") || lowered.contains("mx ") {
                                    kind = .mouse
                                } else if minorType.contains("trackpad") || lowered.contains("trackpad") {
                                    kind = .trackpad
                                } else {
                                    kind = .other
                                }

                                seenNames.insert(deviceName)
                                accessories.append(
                                    BluetoothAccessoryBattery(
                                        id: (info["device_address"] as? String) ?? deviceName,
                                        name: deviceName,
                                        kind: kind,
                                        isConnected: isConn,
                                        primaryPercent: primary,
                                        leftPercent: leftPct,
                                        rightPercent: rightPct,
                                        casePercent: casePct
                                    )
                                )
                            }
                        }
                    }
                }
            }
        } catch {}

        return ScanOutput(accessories: accessories, nearbyBluetoothAppleDeviceNames: nearbyAppleNames)
    }

    private static func parsePercent(_ raw: Any?) -> Int? {
        if let num = raw as? Int { return num }
        if let str = raw as? String {
            let digits = str.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            return Int(digits)
        }
        return nil
    }
}
