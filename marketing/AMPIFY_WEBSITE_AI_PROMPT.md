# Ampify (`cogify.me/ampify`) — Complete Website AI Prompt & Marketing Copy Kit

Use the prompt and structured copy below to build the **`https://cogify.me/ampify`** product landing page in the exact **Cogify (`cogify.me` / `cogify.me/helium`)** design system.

---

## 1. Links & Release Assets
- **Product URL**: `https://cogify.me/ampify`
- **GitHub Repository (Open Source, MIT)**: `https://github.com/Shubham-sharma8/ampify`
- **Direct Signed DMG Download (`v1.6.3`)**: `https://github.com/Shubham-sharma8/ampify/releases/download/v1.6.3/Ampify.dmg`
- **Versioned Signed DMG Download (`v1.6.3`)**: `https://github.com/Shubham-sharma8/ampify/releases/download/v1.6.3/Ampify-1.6.3.dmg`
- **GitHub Release Page**: `https://github.com/Shubham-sharma8/ampify/releases/tag/v1.6.3`
- **Developer Signature**: Signed with `Developer ID Application: Shubham Sharma (9TKKPN6F59)` (Universal `arm64` + `x86_64`, macOS 14.0+ Sonoma, Sequoia & Tahoe).
- **Canva App Icon Asset**: [Open generated image](https://www.canva.com/M/MAHashmrO3Y?utm_source=OC-AZb1vOWcedZR&utm_campaign=agent_connector_create_image_asset_opened)

---

## 2. Copy-Paste AI Prompt to Build `cogify.me/ampify`

```markdown
Build a flagship product page for **Ampify** at `https://cogify.me/ampify` matching the exact design language of `https://cogify.me/helium` and `https://cogify.me`:
- Calm, editorial macOS system typography (regular/medium weights, zero neon gradients or heavy bold text, clean 1px hairlines, subtle pill badges).
- Primary CTA button: "Download for macOS (Free & Open Source)" -> `https://github.com/Shubham-sharma8/ampify/releases/download/v1.6.3/Ampify.dmg`
- Secondary CTA button: "View on GitHub" -> `https://github.com/Shubham-sharma8/ampify`
- Include an interactive feature showcase using the 9 real-app Retina screenshots in `marketing/screenshots/`:
  1. `01-ampify-hero-popover-and-liquid-devices.png` (Hero: Menu Bar Popover + 80% Hold + Liquid-Wave Apple Devices + Now Dashboard)
  2. `02-ampify-apple-devices-liquid-strip-and-health.png` (Liquid-Wave Apple Ecosystem Strip: iPhone, iPad, Watch, AirPods, Pencil, Apple TV Remote + Battery Health Banner)
  3. `03-ampify-whats-using-power-live-watts.png` ("What's using power" Live Hardware Wattage Breakdown + One-Click App Quit Actions)
  4. `04-ampify-desktop-widgets-showcase.png` (5 Native macOS Desktop & Notification Center Widgets in Small, Medium & Large)
  5. `05-ampify-80-percent-hold-and-power-flow.png` (Native PowerUI 80% Charge Hold + 3-Node Live Power Flow + Calibration Watchdog)
  6. `06-ampify-longevity-and-service-price.png` (Capacity Trend vs. 80% Apple Service Line + 1-Page PDF Export + Official Apple Service Price Lookup)
  7. `07-ampify-smart-trip-and-departure-topup.png` (Weekly Time Above 80% + Calendar Trip Auto-Top-Up + Learned Weekday Departure)
  8. `08-ampify-macos-ecosystem-devices-dashboard.png` (Wireless CoreDevice Wi-Fi Discovery for iPhone, iPad & Apple Watch + Bluetooth Peripherals)
  9. `09-ampify-dmg-installer-preview.png` (One-Drag DMG Installer Preview)
```

---

## 3. About Ampify & What It's Good At

### About This App
**Ampify** is a calm, open-source macOS battery longevity and Apple ecosystem battery monitor built for people who keep their MacBook plugged in at a desk or want every Apple device's battery visible in one place. Designed with the **Cogify Helium System UI** philosophy, Ampify translates raw hardware telemetry (`IOKit`, `PowerUI`, `CoreDevice`, and `proc_pid_rusage`) into plain-English guidance—with a one-click `Simple / Technical` switch whenever you want volts, amps, watts, and mAh.

### What Ampify Is Best At
1. **Holding Charge at 80% Without Invasive Root Daemons**: Most charge limiters install a persistent root helper daemon that writes raw SMC keys. Ampify talks directly to macOS's built-in `PowerUI.framework` (`PowerUISmartChargeClient`)—the same engine macOS uses natively—so sleep, wake, and MagSafe LED states behave cleanly.
2. **Showing Every Apple Device Battery in Liquid-Wave Silhouettes**: Displays live liquid-wave battery fills for **iPhone, iPad, Apple Watch, AirPods (L/R/Case), Apple Pencil Pro, Apple TV Siri Remote, MacBook, and Magic Mouse / Keyboard / Trackpad**, complete with charging bolts and rising bubbles.
3. **Reading iPhone, iPad & Apple Watch Over Wi-Fi Automatically**: Wakes the iOS 17+ / macOS wireless `CoreDevice` tunnel in the background so your iPhone and paired Apple Watch show live battery % and charging state over Wi-Fi without plugging in a cable.
4. **Measuring Real App Power in Watts ("What's Using Power")**: Instead of macOS's abstract "Energy Impact" score, Ampify reads Apple Silicon hardware energy counters (`ri_energy_nj`) and shows exact wattage (`0.4 W going to your apps right now`) across your running apps, **`macOS itself`**, and **`Everything else`**, with one-click actions to quit power-hungry apps.
5. **Bringing 5 Native Widgets to Your Mac Desktop**: Bundles a signed, sandboxed `AmpifyWidgetExtension.appex` with 5 WidgetKit widgets (`Apple Devices Liquid Strip`, `iPad, Pencil, Watch & Apple TV`, `What's Using Power`, `Battery & 80% Hold`, and `Battery Health & Power`).

---

## 4. Feature Breakdown for Website Bento Grid

| Feature Card | Headline | Description | Screenshot |
| :--- | :--- | :--- | :--- |
| **01. Liquid-Wave Apple Devices** | **Every Apple device battery, filled like liquid.** | Watch your iPhone, iPad, Apple Watch, AirPods, Apple Pencil, and Apple TV Remote fill with a smooth mint-green liquid wave. Charging devices glow with a lightning bolt and rising bubbles. | `02-ampify-apple-devices-liquid-strip-and-health.png` |
| **02. What's Using Power** | **Real Watts going to your apps right now.** | See whether your Mac is calm (`0.4 W — Nothing is working hard right now`) or which app is draining your battery, plus `macOS itself` and `Everything else`, with one-click app quit actions. | `03-ampify-whats-using-power-live-watts.png` |
| **03. 5 Desktop Widgets** | **Native Sonoma, Sequoia & Tahoe widgets.** | Place the 4-Device Liquid Strip, the iPad + Pencil + Watch + Apple TV widget, or the live App Power widget right on your Mac desktop. | `04-ampify-desktop-widgets-showcase.png` |
| **04. Smart 80% Hold** | **Hold at 80%. Charge to 100% Once when needed.** | Bypass battery cycles while plugged into wall power at your desk. Going out? Click *Charge to 100% Once* and Ampify restores your 80% limit automatically when you unplug. | `05-ampify-80-percent-hold-and-power-flow.png` |
| **05. Longevity & Service Cost** | **Know your battery fade rate and Apple service price.** | Track maximum capacity % against Apple's 80% service threshold, export a 1-page PDF report, and check official Apple out-of-warranty replacement prices offline across 6 countries. | `06-ampify-longevity-and-service-price.png` |
| **06. Calendar & Departure Top-Up** | **80% at your desk. 100% before your flight.** | Ampify scans local Calendar events for upcoming flights or trips and learns your weekday unplug time so you never leave home with an 80% battery when you need 100%. | `07-ampify-smart-trip-and-departure-topup.png` |

---

## 5. Comparison Table: Ampify vs. Traditional Charge Limiters

| Capability | **Ampify (Open Source)** | AlDente / SMC Root Tools | Built-in macOS Battery Settings |
| :--- | :---: | :---: | :---: |
| **80% Charge Limit** | Native `PowerUI` (No root helper) | Privileged root SMC helper | Automatic only (cannot force 80%) |
| **Liquid-Wave Apple Device Silhouettes** | iPhone, iPad, Watch, AirPods, Pencil, Apple TV, Mac | No | No |
| **Wi-Fi iPhone, iPad & Watch Discovery** | Automatic `CoreDevice` + `MobileDevice` wake | No | No |
| **"What's Using Power" in Real Watts** | Live Watts (`0.4 W`) + `macOS itself` + Quit action | Paid Pro only | Vague list without wattage |
| **macOS Desktop Widgets** | 5 native widgets (Small, Medium, Large) | Limited | Basic circle/bars only |
| **Calendar Trip Auto-Top-Up** | Built-in local `EventKit` scanner | No | No |
| **Apple Service Replacement Cost Lookup** | Offline 6-region catalog + 1-page PDF export | No | No |
| **Price & License** | **100% Free & Open Source (MIT)** | Paid subscription / license | Included with macOS |

---

## 6. Frequently Asked Questions (FAQ)

### Q1: Does Ampify install a privileged root helper or modify SMC keys?
**No.** Ampify never installs a background root daemon and never modifies low-level SMC keys. It communicates with macOS's native `PowerUI.framework` (`PowerUISmartChargeClient`)—the same system framework macOS uses for Optimized Battery Charging—so your Mac remains completely safe across macOS updates and sleep cycles.

### Q2: How does Ampify see my iPhone, iPad, and Apple Watch battery over Wi-Fi?
Once you have paired your iPhone or iPad with your Mac in Finder and enabled **"Show this iPhone when on Wi-Fi"**, Ampify automatically wakes the macOS `CoreDevice` wireless tunnel in the background and queries `MobileDevice.framework` (`com.apple.mobile.battery` and `com.apple.companion_proxy` for your paired Apple Watch). No USB cable is required after initial pairing.

### Q3: Which Apple devices are supported in the Liquid-Wave Battery Strip and Widgets?
Ampify supports **This Mac**, **iPhone**, **iPad**, **Apple Watch**, **AirPods / AirPods Pro / AirPods Max / Beats** (including Left, Right, and Case percentages), **Apple Pencil / Apple Pencil Pro**, **Apple TV Siri Remote**, **Magic Keyboard**, **Magic Mouse**, and **Magic Trackpad**.

### Q4: Why does macOS sometimes charge past 80% even with the limit turned on?
Every few weeks, macOS's `powerd` daemon runs an automatic battery gauge calibration (`batterygauging`) to keep your battery percentage accurate. Ampify's built-in **Limit Watchdog** detects when macOS is calibrating, explains why it passed 80%, and automatically re-asserts your 80% hold once calibration finishes.

### Q5: How do I add Ampify's widgets to my Mac desktop?
1. Drag `Ampify.app` into `/Applications` and launch it once.
2. Right-click anywhere on your Mac Desktop and select **Edit Widgets…**.
3. Search for **Ampify** in the Widget Gallery and drag any of the 5 widgets (**Apple Devices Liquid Strip**, **iPad, Pencil, Watch & Apple TV**, **What's Using Power**, **Battery & 80% Hold**, or **Battery Health & Power**) onto your desktop.

### Q6: Is Ampify really free and open source?
**Yes.** Ampify is 100% free and open source under the **MIT License**, with zero telemetry, zero analytics, and zero cloud accounts. Every battery ledger, calendar scan, and hardware reading stays locally on your Mac.
