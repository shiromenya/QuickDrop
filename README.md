# QuickDrop

[日本語版 README はこちら](README.ja.md)

**QuickDrop** is a lightweight, open-source macOS menu bar utility that gently illuminates the **left, top, and right edges** of your screen whenever you drag a file. Touch and drop the file on any lit edge, watch it float smoothly off-screen, and immediately open the native **AirDrop** share sheet — **without ever moving or duplicating your original file**.

---

## Features

- **3-Edge Ambient Glow (Bottom Excluded)**
  - Only the **Left, Top, and Right** edges glow, keeping the Dock area along the bottom edge completely undisturbed.
  - Hovering an edge intensifies its glow and reveals a localized `Send via AirDrop` (or `Share…`) badge pill.
  - Dropping an item plays a smooth visual float-out animation using a QuickLook thumbnail (or instant file icon fallback) while leaving the physical file untouched at its original location.
- **Original File Position Preserved**
  - Negotiates strictly non-destructive `.copy` / `.generic` drag operations (never `.move`), and hands the original file URL directly to the share action without relocating or duplicating files.
- **Direct AirDrop, Share Menu, Per-Edge Actions & Auto-ZIP**
  - Choose between opening **AirDrop directly** (`NSSharingService(named: .sendViaAirDrop)`) or showing the **macOS Share Menu** (`NSSharingServicePicker`), and even assign different actions to Left, Top, and Right edges.
  - Optional **Auto-ZIP** before sharing (for multiple files / folders, always, or on demand by holding `Shift` while dropping), with automatic cleanup of temporary archives.
  - Resend items directly from the **Recent Shares** menu bar history (stored in memory only).
  - Non-modal floating HUD toast notifications inform you cleanly if AirDrop or a sharing service is unavailable without interrupting your workflow.
- **Smart Multi-Display Support**
  - Automatically detects and excludes internal borders shared between adjacent displays so dragging files across monitors never triggers QuickDrop unexpectedly.
  - Choose between **All Enabled Displays** and **Active Cursor Display Only**, or enable/disable individual monitors directly from the menu bar or Settings window.
- **Anti-Accidental-Trigger Controls & Quick Snooze**
  - **Edge Hover Guard**: Add an optional dwell delay (`0s`, `0.12s`, or `0.25s`) so fleetingly brushing the edge never triggers an accidental drop.
  - **Temporary Pause (Snooze)**: Pause QuickDrop for **30 minutes** or **1 hour** straight from the menu bar, or resume immediately anytime.
  - **Modifier Key Control**: Choose between *Always active*, *Disable while holding Option (⌥)*, or *Only active while holding Option (⌥)*.
  - **Per-App Exclusion**: Exclude the frontmost app (e.g. Figma, Photoshop, games) from either the menu bar or the Settings window.
  - **Individual Edge Toggles & Hot-Corner Inset**: Toggle Left / Top / Right edges independently and avoid macOS Hot Corners.
  - **Adjustable Edge Hit Width**: Narrow (`8pt`), Standard (`14pt`), or Wide (`24pt`).
- **Native Settings Window (`⌘,`), Welcome Guide & Live Preview**
  - Configure appearance, displays, drop behavior, excluded apps, and Launch at Login in a grouped SwiftUI Settings window, complete with a one-click **Preview Glow** test button and first-launch Welcome Guide.
  - Respects macOS **Reduce Motion** accessibility settings automatically, and follows your **English** / **Japanese** system language.
- **Feedback, Updates & Web Drag Support**
  - Trackpad haptic click (`NSHapticFeedbackManager`) on edge hover and an optional subtle drop sound effect.
  - Built-in **Check for Updates** via GitHub Releases (with automatic daily background check toggle) and a Homebrew Cask formula template at `packaging/homebrew/quickdrop.rb`.
  - Optional support for dragging web images (converted safely via temporary PNGs and cleaned up afterward) and HTTP/HTTPS links.
- **Launch at Login**
  - Built-in `SMAppService.mainApp` integration (with System Settings approval prompt helper when running from a `.app` bundle).

---

## Requirements

- macOS 13.0 (Ventura) or later
- For building from source: Xcode 15+ or Swift 5.9+

---

## Installation & First Launch (Gatekeeper Note)

Pre-built binaries from GitHub Releases are ad-hoc signed without an Apple Developer ID / notarization certificate. On first launch, macOS Gatekeeper may display a warning ("cannot be opened because the developer cannot be verified").

To open QuickDrop:

1. Move `QuickDrop.app` into `/Applications`.
2. Right-click (or Control-click) `QuickDrop.app` → **Open**, or go to **System Settings → Privacy & Security → Open Anyway**.
3. Alternatively, clear the quarantine attribute via Terminal:
   ```bash
   xattr -cr /Applications/QuickDrop.app
   ```

---

## Building from Source

### Build `.app` Bundle (Recommended)

```bash
git clone https://github.com/shiromenya/QuickDrop.git
cd QuickDrop
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open build/QuickDrop.app
```

This compiles the release binary, generates `QuickDrop.icns` via `scripts/generate-icon.swift` + `iconutil`, packages `build/QuickDrop.app`, and applies ad-hoc code signing.

### Run via SwiftPM / Xcode & Execute Tests

```bash
# Run unit tests
swift test

# Run directly from SwiftPM
swift run

# Open in Xcode
open Package.swift
```

---

## Architecture

```text
Sources/
├── QuickDrop/
│   └── QuickDropApp.swift                  # Thin @main executable entry point
└── QuickDropCore/
    ├── AppDelegate.swift                   # App lifecycle, screen observer, settings & overlay wiring
    ├── Models/
    │   ├── ScreenEdge.swift                # 3-edge geometry & adjacent display filtering
    │   └── DraggedPayload.swift            # Pasteboard extraction (files, images, web URLs)
    ├── Services/
    │   ├── GlobalDragMonitor.swift         # NSEvent + NSPasteboard(.drag) + modifier/app checks
    │   ├── FilePreviewProvider.swift       # Async QuickLook thumbnail prefetch & icon fallback
    │   ├── AirDropService.swift            # Direct AirDrop / NSSharingServicePicker + temp cleanup
    │   ├── ZipArchiver.swift               # Non-destructive temporary .zip packaging via ditto
    │   ├── RecentShareHistory.swift        # In-memory recent shares history for quick resend
    │   ├── UpdateChecker.swift             # GitHub Releases version check & semantic parsing
    │   └── QuickDropSettings.swift         # UserDefaults, snooze timer, display & SMAppService prefs
    ├── UI/
    │   ├── EdgeGlowView.swift              # 3-edge ambient glow + float-out ghost (Reduce Motion aware)
    │   ├── EdgeDropPanel.swift             # Thin NSDraggingDestination strips + hover delay guard
    │   ├── EdgeOverlayCoordinator.swift    # Multi-display focus, preview glow, sound & haptic feedback
    │   ├── MenuBarController.swift         # Menu bar controls, snooze, display & app exclusion menu
    │   ├── OnboardingView.swift            # First-launch Welcome Guide window
    │   ├── SettingsView.swift              # SwiftUI grouped Preferences window (⌘,)
    │   └── ToastHUDWindow.swift            # Non-modal floating HUD toast notifications
    ├── Utilities/
    │   └── L10n.swift                      # Localized resource bundle resolution (EN / JA)
    └── Resources/
        ├── en.lproj/Localizable.strings    # English UI strings
        └── ja.lproj/Localizable.strings    # Japanese UI strings
```
<!-- Homebrew Cask template available in packaging/homebrew/quickdrop.rb -->

---

## License

[MIT License](LICENSE)
