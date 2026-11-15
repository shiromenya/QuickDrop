import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let settings: QuickDropSettings
    private let onPreviewGlow: () -> Void
    private var window: NSWindow?

    init(settings: QuickDropSettings, onPreviewGlow: @escaping () -> Void) {
        self.settings = settings
        self.onPreviewGlow = onPreviewGlow
        super.init()
    }

    func showWindow() {
        if let existing = window {
            NSApp.activateQuickDrop()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = OnboardingView(
            settings: settings,
            onPreviewGlow: onPreviewGlow,
            onComplete: { [weak self] in
                self?.completeAndClose()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 490),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("onboarding.window_title")
        window.contentViewController = hostingController
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        NSApp.activateQuickDrop()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        settings.hasCompletedOnboarding = true
    }

    private func completeAndClose() {
        settings.hasCompletedOnboarding = true
        window?.close()
    }
}

private struct OnboardingView: View {
    @ObservedObject var settings: QuickDropSettings
    let onPreviewGlow: () -> Void
    let onComplete: () -> Void

    @State private var loginErrorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.cyan.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(L10n.tr("onboarding.heading"))
                    .font(.title2.bold())

                Text(L10n.tr("onboarding.subheading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 14) {
                featureRow(
                    symbol: "sparkles",
                    title: L10n.tr("onboarding.step1.title"),
                    detail: L10n.tr("onboarding.step1.detail")
                )
                featureRow(
                    symbol: "arrow.up.forward.app",
                    title: L10n.tr("onboarding.step2.title"),
                    detail: L10n.tr("onboarding.step2.detail")
                )
                featureRow(
                    symbol: "display.2",
                    title: L10n.tr("onboarding.step3.title"),
                    detail: L10n.tr("onboarding.step3.detail")
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            if settings.canConfigureLaunchAtLogin {
                Toggle(L10n.tr("onboarding.launch_toggle"), isOn: Binding(
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 4)

            HStack {
                Button(L10n.tr("onboarding.preview_button")) {
                    onPreviewGlow()
                }

                Spacer()

                Button(L10n.tr("onboarding.get_started")) {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 470, height: 490)
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

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
