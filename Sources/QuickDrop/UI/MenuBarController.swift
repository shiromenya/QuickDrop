import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let settings: QuickDropSettings
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(settings: QuickDropSettings) {
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusButton()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        let symbol = NSImage(
            systemSymbolName: "dot.radiowaves.left.and.right",
            accessibilityDescription: "QuickDrop"
        )
        symbol?.isTemplate = true
        button.image = symbol
        button.toolTip = "QuickDrop"
        updateStatusIconAppearance()
    }

    private func updateStatusIconAppearance() {
        statusItem.button?.appearsDisabled = !settings.isEnabled
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        updateStatusIconAppearance()

        let enableItem = NSMenuItem(
            title: "QuickDrop を有効にする",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enableItem.target = self
        enableItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // Color presets submenu
        let colorMenu = NSMenu()
        for preset in GlowColorPreset.allCases {
            let item = NSMenuItem(
                title: preset.displayName,
                action: #selector(selectColorPreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.rawValue
            item.state = (settings.colorPreset == preset) ? .on : .off
            colorMenu.addItem(item)
        }
        let colorRoot = NSMenuItem(title: "光の色", action: nil, keyEquivalent: "")
        colorRoot.submenu = colorMenu
        menu.addItem(colorRoot)

        // Intensity submenu
        let intensityMenu = NSMenu()
        for intensity in GlowIntensity.allCases {
            let item = NSMenuItem(
                title: intensity.displayName,
                action: #selector(selectIntensity(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = intensity.rawValue
            item.state = (settings.intensity == intensity) ? .on : .off
            intensityMenu.addItem(item)
        }
        let intensityRoot = NSMenuItem(title: "光の強さ", action: nil, keyEquivalent: "")
        intensityRoot.submenu = intensityMenu
        menu.addItem(intensityRoot)

        let cornerItem = NSMenuItem(
            title: "四隅を避ける（ホットコーナー対策）",
            action: #selector(toggleAvoidHotCorners),
            keyEquivalent: ""
        )
        cornerItem.target = self
        cornerItem.state = settings.avoidHotCorners ? .on : .off
        menu.addItem(cornerItem)

        menu.addItem(.separator())

        let loginStatus = settings.launchAtLoginStatus
        let loginTitle: String = switch loginStatus {
        case .requiresApproval:
            "ログイン時に起動（承認待ち）"
        default:
            "ログイン時に起動"
        }
        let loginItem = NSMenuItem(
            title: loginTitle,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = switch loginStatus {
        case .enabled: .on
        case .requiresApproval: .mixed
        default: .off
        }
        loginItem.isEnabled = settings.canConfigureLaunchAtLogin
        if !settings.canConfigureLaunchAtLogin {
            loginItem.toolTip = ".app バンドルとして実行時に有効化できます"
        }
        menu.addItem(loginItem)

        if settings.requiresLaunchAtLoginApproval {
            let approveItem = NSMenuItem(
                title: "システム設定で承認を開く…",
                action: #selector(openLoginItemsSettings),
                keyEquivalent: ""
            )
            approveItem.target = self
            menu.addItem(approveItem)
        }

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "QuickDrop について",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "QuickDrop を終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        updateStatusIconAppearance()
    }

    @objc private func selectColorPreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = GlowColorPreset(rawValue: raw) else {
            return
        }
        settings.colorPreset = preset
    }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let intensity = GlowIntensity(rawValue: raw) else {
            return
        }
        settings.intensity = intensity
    }

    @objc private func toggleAvoidHotCorners() {
        settings.avoidHotCorners.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let shouldEnable = !(settings.isLaunchAtLoginEnabled || settings.requiresLaunchAtLoginApproval)
        do {
            try settings.setLaunchAtLogin(shouldEnable)
            if settings.requiresLaunchAtLoginApproval {
                settings.openLoginItemsSettings()
            }
        } catch {
            NSApp.activateQuickDrop()
            let alert = NSAlert()
            alert.messageText = "ログイン項目の設定を変更できませんでした"
            alert.informativeText = """
            \(error.localizedDescription)

            QuickDrop.app を「アプリケーション」フォルダへ移動するか、
            システム設定 ＞ 一般 ＞ ログイン項目 から手動で追加してください。
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "システム設定を開く")
            alert.addButton(withTitle: "閉じる")
            if alert.runModal() == .alertFirstButtonReturn {
                settings.openLoginItemsSettings()
            }
        }
    }

    @objc private func openLoginItemsSettings() {
        settings.openLoginItemsSettings()
    }

    @objc private func showAbout() {
        NSApp.activateQuickDrop()
        let alert = NSAlert()
        alert.messageText = "QuickDrop"
        alert.informativeText = """
        ファイルをドラッグすると画面の上・左・右のフチがほのかに光り、
        そのまま端に触れてドロップするだけで AirDrop を起動します。
        元のファイルの位置やフォルダは変更されません。
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
