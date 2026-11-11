# QuickDrop

[日本語版 README はこちら](README.ja.md)

**QuickDrop** is a lightweight, open-source macOS menu bar utility that gently illuminates the **left, top, and right edges** of your screen whenever you drag a file. Touch and drop the file on any lit edge, watch it float smoothly off-screen, and immediately open the native **AirDrop** share sheet — **without ever moving or duplicating your original file**.

---

## Features

- **3-Edge Ambient Glow (Bottom Excluded)**
  - Only the **Left, Top, and Right** edges glow, keeping the Dock area along the bottom edge completely undisturbed.
  - Hovering an edge intensifies its glow and reveals an `AirDrop で送信` badge pill.
  - Dropping an item plays a smooth visual float-out animation using a QuickLook thumbnail (or instant file icon fallback) while leaving the physical file untouched at its original location.
- **Original File Position Preserved**
  - Negotiates strictly non-destructive `.copy` / `.generic` drag operations (never `.move`), and passes the original file URL directly to `NSSharingService(named: .sendViaAirDrop)`.
- **Smart Multi-Display Support**
  - Automatically detects and excludes internal borders shared between adjacent displays so dragging files across monitors never triggers QuickDrop unexpectedly.
- **Anti-Accidental-Trigger Controls**
  - **Modifier Key Control**: Choose between *Always active*, *Disable while holding Option (⌥)*, or *Only active while holding Option (⌥)*.
  - **Per-App Exclusion**: Exclude the frontmost app (e.g. Figma, Photoshop, games) straight from the menu bar.
  - **Individual Edge Toggles & Hot-Corner Inset**: Toggle Left / Top / Right edges independently and avoid macOS Hot Corners.
  - **Adjustable Edge Hit Width**: Narrow (`8pt`), Standard (`14pt`), or Wide (`24pt`).
- **Haptic Feedback & Optional Web Drag Support**
  - Trackpad haptic click (`NSHapticFeedbackManager`) when touching an active edge.
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
│   └── QuickDropApp.swift              # Thin @main executable entry point
└── QuickDropCore/
    ├── AppDelegate.swift               # App lifecycle, screen change observer, wiring
    ├── Models/
    │   ├── ScreenEdge.swift            # 3-edge geometry & adjacent display filtering
    │   └── DraggedPayload.swift        # Pasteboard extraction (files, images, web URLs)
    ├── Services/
    │   ├── GlobalDragMonitor.swift     # NSEvent + NSPasteboard(.drag) + modifier/app checks
    │   ├── FilePreviewProvider.swift   # Async QuickLook thumbnail prefetch & icon fallback
    │   ├── AirDropService.swift        # NSSharingService(.sendViaAirDrop) + temp cleanup
    │   └── QuickDropSettings.swift     # UserDefaults & SMAppService preferences
    └── UI/
        ├── EdgeGlowView.swift          # 3-edge ambient glow + float-out ghost animation
        ├── EdgeDropPanel.swift         # Thin borderless NSDraggingDestination strips
        ├── EdgeOverlayCoordinator.swift# Multi-display coordination & haptic feedback
        └── MenuBarController.swift     # Menu bar controls & app exclusion menu
```

---

## License

[MIT License](LICENSE)
