import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let settings: QuickDropSettings
    private let recentHistory: RecentShareHistory
    private let onResendRecent: (RecentShareEntry) -> Void
    private let onOpenSettings: () -> Void
    private let onPreviewGlow: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onShowOnboarding: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var capturedFrontmostApp: ExcludedApp?

    init(
        settings: QuickDropSettings,
        recentHistory: RecentShareHistory,
        onResendRecent: @escaping (RecentShareEntry) -> Void,
        onOpenSettings: @escaping () -> Void,
        onPreviewGlow: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onShowOnboarding: @escaping () -> Void
    ) {
        self.settings = settings
        self.recentHistory = recentHistory
        self.onResendRecent = onResendRecent
        self.onOpenSettings = onOpenSettings
        self.onPreviewGlow = onPreviewGlow
        self.onCheckForUpdates = onCheckForUpdates
        self.onShowOnboarding = onShowOnboarding
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

    func refreshStatusAppearance() {
        statusItem.button?.appearsDisabled = !settings.isEffectivelyEnabled
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
        refreshStatusAppearance()
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
        refreshStatusAppearance()

        menu.addItem(makeActionItem(
            title: L10n.tr("menu.enable"),
            action: #selector(toggleEnabled),
            state: settings.isEnabled ? .on : .off
        ))

        if settings.isEnabled {
            if let remaining = settings.remainingSnoozeMinutes {
                menu.addItem(makeActionItem(
                    title: L10n.fmt("menu.snoozed_resume", remaining),
                    action: #selector(resumeFromSnooze)
                ))
            } else {
                menu.addItem(makeSnoozeSubmenu())
            }
        }

        menu.addItem(.separator())

        menu.addItem(makeColorSubmenu())
        menu.addItem(makeIntensitySubmenu())
        menu.addItem(makeHitThicknessSubmenu())
        menu.addItem(makeEdgesSubmenu())
        menu.addItem(makeDisplaysSubmenu())
        menu.addItem(makeModifierModeSubmenu())
        menu.addItem(makeHoverDelaySubmenu())
        menu.addItem(makeShareBehaviorSubmenu())
        menu.addItem(makeEdgeActionsSubmenu())
        menu.addItem(makeZipArchiveSubmenu())

        menu.addItem(makeActionItem(
            title: L10n.tr("menu.avoid_corners"),
            action: #selector(toggleAvoidHotCorners),
            state: settings.avoidHotCorners ? .on : .off
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.haptics"),
            action: #selector(toggleHapticFeedback),
            state: settings.hapticFeedbackEnabled ? .on : .off
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.sound_feedback"),
            action: #selector(toggleSoundFeedback),
            state: settings.soundFeedbackEnabled ? .on : .off
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.web_drags"),
            action: #selector(toggleWebAndImageDrags),
            state: settings.allowWebAndImageDrags ? .on : .off
        ))

        menu.addItem(.separator())

        if let frontApp = capturedFrontmostApp {
            let isExcluded = settings.isAppExcluded(bundleIdentifier: frontApp.bundleIdentifier)
            menu.addItem(makeActionItem(
                title: L10n.fmt("menu.exclude_frontmost", frontApp.displayName),
                action: #selector(toggleCapturedFrontmostApp),
                state: isExcluded ? .on : .off
            ))
        }
        menu.addItem(makeExcludedAppsSubmenu())
        menu.addItem(makeRecentSharesSubmenu())

        menu.addItem(.separator())

        addLoginItemsSection()

        menu.addItem(.separator())

        menu.addItem(makeActionItem(
            title: L10n.tr("menu.preview_glow"),
            action: #selector(previewGlow)
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.settings"),
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.check_updates"),
            action: #selector(checkForUpdates)
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.welcome_guide"),
            action: #selector(openWelcomeGuide)
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.about"),
            action: #selector(showAbout)
        ))
        menu.addItem(makeActionItem(
            title: L10n.tr("menu.quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))
    }

    // MARK: - Submenus

    private func makeSnoozeSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        submenu.addItem(makeActionItem(
            title: L10n.tr("menu.snooze_30m"),
            action: #selector(snoozeThirtyMinutes)
        ))
        submenu.addItem(makeActionItem(
            title: L10n.tr("menu.snooze_1h"),
            action: #selector(snoozeOneHour)
        ))
        return makeSubmenuRoot(title: L10n.tr("menu.snooze"), submenu: submenu)
    }

    private func makeColorSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for preset in GlowColorPreset.allCases {
            submenu.addItem(makeActionItem(
                title: preset.displayName,
                action: #selector(selectColorPreset(_:)),
                state: settings.colorPreset == preset ? .on : .off,
                representedObject: preset.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.glow_color"), submenu: submenu)
    }

    private func makeIntensitySubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for intensity in GlowIntensity.allCases {
            submenu.addItem(makeActionItem(
                title: intensity.displayName,
                action: #selector(selectIntensity(_:)),
                state: settings.intensity == intensity ? .on : .off,
                representedObject: intensity.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.glow_intensity"), submenu: submenu)
    }

    private func makeHitThicknessSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for preset in DropHitThicknessPreset.allCases {
            submenu.addItem(makeActionItem(
                title: preset.displayName,
                action: #selector(selectHitThickness(_:)),
                state: settings.hitThicknessPreset == preset ? .on : .off,
                representedObject: preset.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.hit_width"), submenu: submenu)
    }

    private func makeEdgesSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for edge in ScreenEdge.allCases {
            submenu.addItem(makeActionItem(
                title: edge.displayName,
                action: #selector(toggleEdge(_:)),
                state: settings.enabledEdges.contains(edge) ? .on : .off,
                representedObject: edge.rawValue
            ))
        }
        submenu.addItem(.separator())
        submenu.addItem(makeActionItem(
            title: L10n.tr("menu.exclude_adjacent"),
            action: #selector(toggleExcludeAdjacentEdges),
            state: settings.excludeAdjacentScreenEdges ? .on : .off
        ))
        return makeSubmenuRoot(title: L10n.tr("menu.active_edges"), submenu: submenu)
    }

    private func makeDisplaysSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for scope in DisplayGlowScope.allCases {
            submenu.addItem(makeActionItem(
                title: scope.displayName,
                action: #selector(selectDisplayScope(_:)),
                state: settings.displayGlowScope == scope ? .on : .off,
                representedObject: scope.rawValue
            ))
        }

        let displays = ConnectedDisplayInfo.current()
        if !displays.isEmpty {
            submenu.addItem(.separator())
            for display in displays {
                submenu.addItem(makeActionItem(
                    title: "\(display.name) (\(display.resolutionText))",
                    action: #selector(toggleDisplayEnabled(_:)),
                    state: settings.isDisplayEnabled(display.id) ? .on : .off,
                    representedObject: NSNumber(value: display.id)
                ))
            }
        }
        return makeSubmenuRoot(title: L10n.tr("menu.displays"), submenu: submenu)
    }

    private func makeHoverDelaySubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for preset in HoverDelayPreset.allCases {
            submenu.addItem(makeActionItem(
                title: preset.displayName,
                action: #selector(selectHoverDelay(_:)),
                state: settings.hoverDelayPreset == preset ? .on : .off,
                representedObject: preset.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.hover_delay"), submenu: submenu)
    }

    private func makeModifierModeSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for mode in ModifierActivationMode.allCases {
            submenu.addItem(makeActionItem(
                title: mode.displayName,
                action: #selector(selectModifierMode(_:)),
                state: settings.modifierMode == mode ? .on : .off,
                representedObject: mode.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.modifier_control"), submenu: submenu)
    }

    private func makeShareBehaviorSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for behavior in ShareBehavior.allCases {
            submenu.addItem(makeActionItem(
                title: behavior.displayName,
                action: #selector(selectShareBehavior(_:)),
                state: settings.shareBehavior == behavior ? .on : .off,
                representedObject: behavior.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.share_action"), submenu: submenu)
    }

    private func makeEdgeActionsSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for edge in ScreenEdge.allCases {
            let edgeMenu = NSMenu()
            let currentAction = settings.edgeActionOverride(for: edge)
            for action in EdgeAction.allCases {
                edgeMenu.addItem(makeActionItem(
                    title: action.displayName,
                    action: #selector(selectEdgeAction(_:)),
                    state: currentAction == action ? .on : .off,
                    representedObject: "\(edge.rawValue):\(action.rawValue)"
                ))
            }
            submenu.addItem(makeSubmenuRoot(title: edge.displayName, submenu: edgeMenu))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.edge_actions"), submenu: submenu)
    }

    private func makeZipArchiveSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        for mode in ZipArchiveBehavior.allCases {
            submenu.addItem(makeActionItem(
                title: mode.displayName,
                action: #selector(selectZipArchiveBehavior(_:)),
                state: settings.zipArchiveBehavior == mode ? .on : .off,
                representedObject: mode.rawValue
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.zip_mode"), submenu: submenu)
    }

    private func makeRecentSharesSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        let entries = recentHistory.entries

        if entries.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr("menu.no_recent_shares"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for entry in entries {
                submenu.addItem(makeActionItem(
                    title: entry.title,
                    action: #selector(resendRecentShare(_:)),
                    representedObject: entry.id
                ))
            }
            submenu.addItem(.separator())
            submenu.addItem(makeActionItem(
                title: L10n.tr("menu.clear_recent_shares"),
                action: #selector(clearRecentShares)
            ))
        }
        return makeSubmenuRoot(title: L10n.tr("menu.recent_shares"), submenu: submenu)
    }

    private func makeExcludedAppsSubmenu() -> NSMenuItem {
        let submenu = NSMenu()
        let apps = settings.excludedApps

        if apps.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr("menu.no_excluded_apps"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for app in apps {
                submenu.addItem(makeActionItem(
                    title: L10n.fmt("menu.remove_excluded_app", app.displayName),
                    action: #selector(removeExcludedApp(_:)),
                    representedObject: app.bundleIdentifier
                ))
            }
            submenu.addItem(.separator())
            submenu.addItem(makeActionItem(
                title: L10n.tr("menu.clear_excluded_apps"),
                action: #selector(clearExcludedApps)
            ))
        }
        return makeSubmenuRoot(title: L10n.fmt("menu.excluded_apps_count", apps.count), submenu: submenu)
    }

    private func addLoginItemsSection() {
        let loginStatus = settings.launchAtLoginStatus
        let loginTitle = loginStatus == .requiresApproval
            ? L10n.tr("menu.launch_at_login_pending")
            : L10n.tr("menu.launch_at_login")

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
            loginItem.toolTip = L10n.tr("menu.launch_at_login_tooltip")
        }
        menu.addItem(loginItem)

        if settings.requiresLaunchAtLoginApproval {
            menu.addItem(makeActionItem(
                title: L10n.tr("menu.open_login_approval"),
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
        refreshStatusAppearance()
    }

    @objc private func snoozeThirtyMinutes() {
        settings.snooze(for: 30 * 60)
    }

    @objc private func snoozeOneHour() {
        settings.snooze(for: 60 * 60)
    }

    @objc private func resumeFromSnooze() {
        settings.cancelSnooze()
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

    @objc private func selectShareBehavior(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let behavior = ShareBehavior(rawValue: raw) else { return }
        settings.shareBehavior = behavior
    }

    @objc private func selectEdgeAction(_ sender: NSMenuItem) {
        guard let encoded = sender.representedObject as? String else { return }
        let parts = encoded.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let edge = ScreenEdge(rawValue: parts[0]),
              let action = EdgeAction(rawValue: parts[1]) else {
            return
        }
        settings.setEdgeAction(action, for: edge)
    }

    @objc private func selectZipArchiveBehavior(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ZipArchiveBehavior(rawValue: raw) else { return }
        settings.zipArchiveBehavior = mode
    }

    @objc private func resendRecentShare(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let entry = recentHistory.entries.first(where: { $0.id == id }) else {
            return
        }
        onResendRecent(entry)
    }

    @objc private func clearRecentShares() {
        recentHistory.clear()
    }

    @objc private func selectDisplayScope(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let scope = DisplayGlowScope(rawValue: raw) else { return }
        settings.displayGlowScope = scope
    }

    @objc private func toggleDisplayEnabled(_ sender: NSMenuItem) {
        guard let num = sender.representedObject as? NSNumber else { return }
        settings.toggleExcludedDisplay(num.uint32Value)
    }

    @objc private func selectHoverDelay(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = HoverDelayPreset(rawValue: raw) else { return }
        settings.hoverDelayPreset = preset
    }

    @objc private func toggleAvoidHotCorners() {
        settings.avoidHotCorners.toggle()
    }

    @objc private func toggleHapticFeedback() {
        settings.hapticFeedbackEnabled.toggle()
    }

    @objc private func toggleSoundFeedback() {
        settings.soundFeedbackEnabled.toggle()
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
            alert.messageText = L10n.tr("alert.login_failed.title")
            alert.informativeText = L10n.fmt("alert.login_failed.body", error.localizedDescription)
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.tr("alert.open_system_settings"))
            alert.addButton(withTitle: L10n.tr("alert.close"))
            if alert.runModal() == .alertFirstButtonReturn {
                settings.openLoginItemsSettings()
            }
        }
    }

    @objc private func openLoginItemsSettings() {
        settings.openLoginItemsSettings()
    }

    @objc private func openSettingsWindow() {
        onOpenSettings()
    }

    @objc private func previewGlow() {
        onPreviewGlow()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func openWelcomeGuide() {
        onShowOnboarding()
    }

    @objc private func showAbout() {
        NSApp.activateQuickDrop()
        let alert = NSAlert()
        alert.messageText = L10n.tr("about.title")
        alert.informativeText = L10n.tr("about.body")
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
