import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let settings: QuickDropSettings
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var capturedFrontmostApp: ExcludedApp?

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
        captureFrontmostApp()
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

    private func captureFrontmostApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else {
            capturedFrontmostApp = nil
            return
        }
        let name = frontApp.localizedName ?? bundleID
        capturedFrontmostApp = ExcludedApp(bundleIdentifier: bundleID, displayName: name)
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        updateStatusIconAppearance()

        let enableItem = makeActionItem(
            title: "QuickDrop を有効にする",
            action: #selector(toggleEnabled),
            state: settings.isEnabled ? .on : .off
        )
        menu.addItem(enableItem)

        menu.addItem(.separator())

        menu.addItem(makeColorSubmenu())
        menu.addItem(makeIntensitySubmenu())
        menu.addItem(makeHitThicknessSubmenu())
        menu.addItem(makeEdgesSubmenu())
        menu.addItem(makeModifierModeSubmenu())

        menu.addItem(makeActionItem(
            title: "四隅を避ける（ホットコーナー対策）",
            action: #selector(toggleAvoidHotCorners),
            state: settings.avoidHotCorners ? .on : .off
        ))
        menu.addItem(makeActionItem(
            title: "触覚フィードバック（トラックパッド）",
            action: #selector(toggleHapticFeedback),
            state: settings.hapticFeedbackEnabled ? .on : .off
        ))
        menu.addItem(makeActionItem(
            title: "Web画像・リンクのドラッグも対象にする",
            action: #selector(toggleWebAndImageDrags),
            state: settings.allowWebAndImageDrags ? .on : .off
        ))

        menu.addItem(.separator())

        if let frontApp = capturedFrontmostApp {
            let isExcluded = settings.isAppExcluded(bundleIdentifier: frontApp.bundleIdentifier)
            menu.addItem(makeActionItem(
                title: "最前面アプリ（\(frontApp.displayName)）を除外",
                action: #selector(toggleCapturedFrontmostApp),
                state: isExcluded ? .on : .off
            ))
        }
        menu.addItem(makeExcludedAppsSubmenu())

        menu.addItem(.separator())

        addLoginItemsSection()

        menu.addItem(.separator())

        menu.addItem(makeActionItem(
            title: "QuickDrop について",
            action: #selector(showAbout)
        ))
        let quitItem = makeActionItem(
            title: "QuickDrop を終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
    }

    // MARK: - Submenus

    private func makeColorSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for preset in GlowColorPreset.allCases {
            let item = makeActionItem(
                title: preset.displayName,
                action: #selector(selectColorPreset(_:)),
                state: settings.colorPreset == preset ? .on : .off,
                representedObject: preset.rawValue
            )
            submenu.addItem(item)
        }
        return makeSubmenuRoot(title: "光の色", submenu: submenu)
    }

    private func makeIntensitySubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for intensity in GlowIntensity.allCases {
            let item = makeActionItem(
                title: intensity.displayName,
                action: #selector(selectIntensity(_:)),
                state: settings.intensity == intensity ? .on : .off,
                representedObject: intensity.rawValue
            )
            submenu.addItem(item)
        }
        return makeSubmenuRoot(title: "光の強さ", submenu: submenu)
    }

    private func makeHitThicknessSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for preset in DropHitThicknessPreset.allCases {
            let item = makeActionItem(
                title: preset.displayName,
                action: #selector(selectHitThickness(_:)),
                state: settings.hitThicknessPreset == preset ? .on : .off,
                representedObject: preset.rawValue
            )
            submenu.addItem(item)
        }
        return makeSubmenuRoot(title: "反応するフチの幅", submenu: submenu)
    }

    private func makeEdgesSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for edge in ScreenEdge.allCases {
            let item = makeActionItem(
                title: edge.displayName,
                action: #selector(toggleEdge(_:)),
                state: settings.enabledEdges.contains(edge) ? .on : .off,
                representedObject: edge.rawValue
            )
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        submenu.addItem(makeActionItem(
            title: "隣り合うディスプレイとの境界を除外",
            action: #selector(toggleExcludeAdjacentEdges),
            state: settings.excludeAdjacentScreenEdges ? .on : .off
        ))
        return makeSubmenuRoot(title: "光る・反応する辺", submenu: submenu)
    }

    private func makeModifierModeSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for mode in ModifierActivationMode.allCases {
            let item = makeActionItem(
                title: mode.displayName,
                action: #selector(selectModifierMode(_:)),
                state: settings.modifierMode == mode ? .on : .off,
                representedObject: mode.rawValue
            )
            submenu.addItem(item)
        }
        return makeSubmenuRoot(title: "修飾キーでの制御", submenu: submenu)
    }

    private func makeExcludedAppsSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        let apps = settings.excludedApps

        if apps.isEmpty {
            let emptyItem = NSMenuItem(title: "除外中のアプリはありません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for app in apps {
                let item = makeActionItem(
                    title: "\(app.displayName) を解除",
                    action: #selector(removeExcludedApp(_:)),
                    representedObject: app.bundleIdentifier
                )
                submenu.addItem(item)
            }
            submenu.addItem(.separator())
            submenu.addItem(makeActionItem(
                title: "すべて解除",
                action: #selector(clearExcludedApps)
            ))
        }
        return makeSubmenuRoot(title: "除外中のアプリ (\(apps.count))", submenu: submenu)
    }

    private func addLoginItemsSection() {
        let loginStatus = settings.launchAtLoginStatus
        let loginTitle = loginStatus == .requiresApproval
            ? "ログイン時に起動（承認待ち）"
            : "ログイン時に起動"

        let loginState: NSControl.StateValue = switch loginStatus {
        case .enabled: .on
        case .requiresApproval: .mixed
        default: .off
        }

        let loginItem = makeActionItem(
            title: loginTitle,
            action: #selector(toggleLaunchAtLogin),
            state: loginState
        )
        loginItem.isEnabled = settings.canConfigureLaunchAtLogin
        if !settings.canConfigureLaunchAtLogin {
            loginItem.toolTip = ".app バンドルとして実行時に有効化できます"
        }
        menu.addItem(loginItem)

        if settings.requiresLaunchAtLoginApproval {
            menu.addItem(makeActionItem(
                title: "システム設定で承認を開く…",
                action: #selector(openLoginItemsSettings)
            ))
        }
    }

    private func makeSubmenuRoot(title: String, submenu: NSMenu) -> NSMenuItem {
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        root.submenu = submenu
        return root
    }

    private func makeActionItem(
        title: String,
        action: Selector,
        state: NSControl.StateValue = .off,
        keyEquivalent: String = "",
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.state = state
        item.representedObject = representedObject
        return item
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        updateStatusIconAppearance()
    }

    @objc private func selectColorPreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = GlowColorPreset(rawValue: raw) else { return }
        settings.colorPreset = preset
    }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let intensity = GlowIntensity(rawValue: raw) else { return }
        settings.intensity = intensity
    }

    @objc private func selectHitThickness(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = DropHitThicknessPreset(rawValue: raw) else { return }
        settings.hitThicknessPreset = preset
    }

    @objc private func toggleEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let edge = ScreenEdge(rawValue: raw) else { return }
        settings.toggleEdge(edge)
    }

    @objc private func toggleExcludeAdjacentEdges() {
        settings.excludeAdjacentScreenEdges.toggle()
    }

    @objc private func selectModifierMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ModifierActivationMode(rawValue: raw) else { return }
        settings.modifierMode = mode
    }

    @objc private func toggleAvoidHotCorners() {
        settings.avoidHotCorners.toggle()
    }

    @objc private func toggleHapticFeedback() {
        settings.hapticFeedbackEnabled.toggle()
    }

    @objc private func toggleWebAndImageDrags() {
        settings.allowWebAndImageDrags.toggle()
    }

    @objc private func toggleCapturedFrontmostApp() {
        guard let frontApp = capturedFrontmostApp else { return }
        settings.toggleExcludedApp(
            bundleIdentifier: frontApp.bundleIdentifier,
            displayName: frontApp.displayName
        )
    }

    @objc private func removeExcludedApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        settings.removeExcludedApp(bundleIdentifier: bundleID)
    }

    @objc private func clearExcludedApps() {
        settings.clearExcludedApps()
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
