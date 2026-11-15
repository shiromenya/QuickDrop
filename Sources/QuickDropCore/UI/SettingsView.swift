import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: QuickDropSettings
    private let updateChecker: UpdateChecker
    private let onPreviewGlow: () -> Void
    private let onShowOnboarding: () -> Void
    private var window: NSWindow?

    init(
        settings: QuickDropSettings,
        updateChecker: UpdateChecker,
        onPreviewGlow: @escaping () -> Void,
        onShowOnboarding: @escaping () -> Void
    ) {
        self.settings = settings
        self.updateChecker = updateChecker
        self.onPreviewGlow = onPreviewGlow
        self.onShowOnboarding = onShowOnboarding
    }

    func showWindow() {
        if let existing = window {
            NSApp.activateQuickDrop()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = SettingsView(
            settings: settings,
            updateChecker: updateChecker,
            onPreviewGlow: onPreviewGlow,
            onShowOnboarding: onShowOnboarding
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("settings.window_title")
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        NSApp.activateQuickDrop()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: QuickDropSettings
    @ObservedObject var updateChecker: UpdateChecker
    let onPreviewGlow: () -> Void
    let onShowOnboarding: () -> Void

    @State private var loginErrorMessage: String?

    var body: some View {
        Form {
            generalSection
            appearanceAndDisplaysSection
            triggersSection
            updatesSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, idealWidth: 500, minHeight: 620, idealHeight: 680)
        .alert(L10n.tr("alert.login_failed.title"), isPresented: Binding(
            get: { loginErrorMessage != nil },
            set: { if !$0 { loginErrorMessage = nil } }
        )) {
            Button(L10n.tr("alert.open_system_settings")) {
                settings.openLoginItemsSettings()
            }
            Button(L10n.tr("alert.close"), role: .cancel) {}
        } message: {
            Text(L10n.fmt("alert.login_failed.body", loginErrorMessage ?? ""))
        }
    }

    private var generalSection: some View {
        Section(L10n.tr("settings.section.general")) {
            Toggle(L10n.tr("menu.enable"), isOn: $settings.isEnabled)

            if settings.isEnabled {
                if let remaining = settings.remainingSnoozeMinutes {
                    HStack {
                        Text(L10n.fmt("settings.snooze_status", remaining))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.tr("settings.resume")) {
                            settings.cancelSnooze()
                        }
                    }
                } else {
                    LabeledContent(L10n.tr("menu.snooze")) {
                        HStack(spacing: 8) {
                            Button(L10n.tr("settings.snooze_30m_short")) {
                                settings.snooze(for: 30 * 60)
                            }
                            Button(L10n.tr("settings.snooze_1h_short")) {
                                settings.snooze(for: 60 * 60)
                            }
                        }
                    }
                }
            }

            Picker(L10n.tr("menu.share_action"), selection: $settings.shareBehavior) {
                ForEach(ShareBehavior.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            DisclosureGroup(L10n.tr("settings.edge_actions_group")) {
                ForEach(ScreenEdge.allCases, id: \.self) { edge in
                    Picker(edge.displayName, selection: Binding(
                        get: { settings.edgeActionOverride(for: edge) },
                        set: { settings.setEdgeAction($0, for: edge) }
                    )) {
                        ForEach(EdgeAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                }
            }

            Picker(L10n.tr("menu.zip_mode"), selection: $settings.zipArchiveBehavior) {
                ForEach(ZipArchiveBehavior.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Text(L10n.tr("settings.zip_shift_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(L10n.tr("menu.hover_delay"), selection: $settings.hoverDelayPreset) {
                ForEach(HoverDelayPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Toggle(L10n.tr("menu.haptics"), isOn: $settings.hapticFeedbackEnabled)
            Toggle(L10n.tr("menu.sound_feedback"), isOn: $settings.soundFeedbackEnabled)

            if settings.canConfigureLaunchAtLogin {
                Toggle(L10n.tr("menu.launch_at_login"), isOn: Binding(
                    get: { settings.isLaunchAtLoginEnabled || settings.requiresLaunchAtLoginApproval },
                    set: { newValue in
                        do {
                            try settings.setLaunchAtLogin(newValue)
                            if settings.requiresLaunchAtLoginApproval {
                                settings.openLoginItemsSettings()
                            }
                        } catch {
                            loginErrorMessage = error.localizedDescription
                        }
                    }
                ))

                if settings.requiresLaunchAtLoginApproval {
                    HStack {
                        Text(L10n.tr("menu.launch_at_login_pending"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(L10n.tr("settings.open_settings_button")) {
                            settings.openLoginItemsSettings()
                        }
                    }
                }
            } else {
                LabeledContent(L10n.tr("menu.launch_at_login")) {
                    Text(L10n.tr("settings.bundle_only_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var appearanceAndDisplaysSection: some View {
        Section(L10n.tr("settings.section.appearance")) {
            Picker(L10n.tr("menu.glow_color"), selection: $settings.colorPreset) {
                ForEach(GlowColorPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            if settings.colorPreset == .custom {
                ColorPicker(
                    L10n.tr("settings.custom_color"),
                    selection: customColorBinding,
                    supportsOpacity: false
                )
            }

            Picker(L10n.tr("menu.glow_intensity"), selection: $settings.intensity) {
                ForEach(GlowIntensity.allCases, id: \.self) { intensity in
                    Text(intensity.displayName).tag(intensity)
                }
            }

            Picker(L10n.tr("menu.hit_width"), selection: $settings.hitThicknessPreset) {
                ForEach(DropHitThicknessPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            LabeledContent(L10n.tr("menu.active_edges")) {
                HStack(spacing: 12) {
                    ForEach(ScreenEdge.allCases, id: \.self) { edge in
                        Toggle(edge.displayName, isOn: Binding(
                            get: { settings.enabledEdges.contains(edge) },
                            set: { enabled in
                                var edges = settings.enabledEdges
                                if enabled {
                                    edges.insert(edge)
                                } else {
                                    edges.remove(edge)
                                }
                                settings.enabledEdges = edges
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Toggle(L10n.tr("menu.avoid_corners"), isOn: $settings.avoidHotCorners)

            Picker(L10n.tr("menu.display_scope"), selection: $settings.displayGlowScope) {
                ForEach(DisplayGlowScope.allCases, id: \.self) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }

            Toggle(L10n.tr("menu.exclude_adjacent"), isOn: $settings.excludeAdjacentScreenEdges)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("settings.connected_displays_label"))
                ForEach(ConnectedDisplayInfo.current()) { display in
                    Toggle(isOn: Binding(
                        get: { settings.isDisplayEnabled(display.id) },
                        set: { enabled in
                            let currentlyEnabled = settings.isDisplayEnabled(display.id)
                            if enabled != currentlyEnabled {
                                settings.toggleExcludedDisplay(display.id)
                            }
                        }
                    )) {
                        HStack {
                            Text(display.name)
                            Spacer()
                            Text(display.resolutionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            LabeledContent(L10n.tr("settings.preview_label")) {
                Button(L10n.tr("settings.preview_button")) {
                    onPreviewGlow()
                }
            }
        }
    }

    private var triggersSection: some View {
        Section(L10n.tr("settings.section.triggers")) {
            Picker(L10n.tr("menu.modifier_control"), selection: $settings.modifierMode) {
                ForEach(ModifierActivationMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Toggle(L10n.tr("menu.web_drags"), isOn: $settings.allowWebAndImageDrags)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.tr("settings.excluded_apps_label"))
                    Spacer()
                    if !settings.excludedApps.isEmpty {
                        Button(L10n.tr("menu.clear_excluded_apps")) {
                            settings.clearExcludedApps()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }

                if settings.excludedApps.isEmpty {
                    Text(L10n.tr("settings.excluded_apps_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.excludedApps) { app in
                        HStack {
                            Text(app.displayName)
                            Spacer()
                            Button {
                                settings.removeExcludedApp(bundleIdentifier: app.bundleIdentifier)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var updatesSection: some View {
        Section(L10n.tr("settings.section.updates")) {
            LabeledContent(L10n.tr("settings.version_label")) {
                Text("v\(updateChecker.currentVersionString)")
                    .foregroundStyle(.secondary)
            }

            Toggle(L10n.tr("settings.auto_check_updates"), isOn: $settings.autoCheckForUpdates)

            HStack {
                Button(L10n.tr("menu.check_updates")) {
                    updateChecker.checkForUpdates(userInitiated: true)
                }
                .disabled(updateChecker.isChecking)

                if updateChecker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }

                Spacer()

                Button(L10n.tr("menu.welcome_guide")) {
                    onShowOnboarding()
                }
            }

            if let outcome = updateChecker.lastOutcome {
                switch outcome {
                case .upToDate(let current):
                    Text(L10n.fmt("updates.inline_up_to_date", current.displayString))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .updateAvailable(_, let latest):
                    HStack {
                        Text(L10n.fmt("updates.inline_available", latest.version.displayString))
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(L10n.tr("updates.open_release_page")) {
                            updateChecker.openReleasePage(url: latest.htmlURL)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            } else if let errorMessage = updateChecker.lastErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    nsColor: NSColor.quickDropFromHex(settings.customGlowColorHex)
                        ?? GlowColorPreset.custom.primaryColor
                )
            },
            set: { newColor in
                settings.colorPreset = .custom
                settings.customGlowColorHex = NSColor(newColor).quickDropHexString
            }
        )
    }
}
