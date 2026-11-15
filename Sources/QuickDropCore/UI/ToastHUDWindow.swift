import AppKit

enum ToastStyle {
    case warning
    case info

    var symbolName: String {
        switch self {
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "sparkles"
        }
    }

    var tintColor: NSColor {
        switch self {
        case .warning: return .systemOrange
        case .info: return .systemBlue
        }
    }
}

/// Displays brief, non-modal HUD toast notifications without interrupting active workflows.
@MainActor
final class ToastHUDPresenter {
    static let shared = ToastHUDPresenter()

    private var hudWindow: NSWindow?
    private var dismissTask: Task<Void, Never>?

    func show(message: String, style: ToastStyle = .warning, on screen: NSScreen? = nil) {
        dismissTask?.cancel()

        let pill = ToastPillView(message: message, style: style)
        pill.layoutSubtreeIfNeeded()
        let size = pill.fittingSize

        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.minY + 54
        )
        let windowFrame = NSRect(origin: origin, size: size)

        let window = hudWindow ?? makeWindow()
        hudWindow = window
        window.contentView = pill
        window.setFrame(windowFrame, display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()

        let fadeDuration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.08 : 0.16
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            window.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard let window = hudWindow else { return }
        let fadeDuration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.1 : 0.22
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            window.animator().alphaValue = 0
        } completionHandler: { [weak window] in
            Task { @MainActor [weak window] in
                window?.orderOut(nil)
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return window
    }
}

@MainActor
private final class ToastPillView: NSVisualEffectView {
    init(message: String, style: ToastStyle) {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

        let iconView = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iconView.image = NSImage(
            systemSymbolName: style.symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        iconView.contentTintColor = style.tintColor

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 2
        label.preferredMaxLayoutWidth = 420

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
