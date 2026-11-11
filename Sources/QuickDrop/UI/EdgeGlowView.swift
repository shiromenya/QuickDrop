import AppKit
import QuartzCore

/// Full-screen, click-through overlay window that renders the subtle ambient glow
/// along the left, top, and right edges (never the bottom edge).
@MainActor
final class AmbientGlowWindow: NSWindow {
    let glowView: EdgeGlowView

    init(screenFrame: NSRect) {
        self.glowView = EdgeGlowView(frame: NSRect(origin: .zero, size: screenFrame.size))

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        alphaValue = 0

        contentView = glowView
    }
}

@MainActor
final class EdgeGlowView: NSView {
    private var auraLayers: [ScreenEdge: CAGradientLayer] = [:]
    private var rimLayers: [ScreenEdge: CAGradientLayer] = [:]
    private let badgeView = EdgeBadgePillView()

    private var currentColor: NSColor = GlowColorPreset.airDropBlue.primaryColor
    private var idleAlpha: CGFloat = GlowIntensity.subtle.idleAlpha
    private var hoveredAlpha: CGFloat = GlowIntensity.subtle.hoveredAlpha
    private var hoveredEdge: ScreenEdge?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupLayers()
        setupBadgeView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutEdgeLayers()
    }

    func applyStyle(color: NSColor, intensity: GlowIntensity) {
        currentColor = color
        idleAlpha = intensity.idleAlpha
        hoveredAlpha = intensity.hoveredAlpha
        refreshGlowAppearance(animated: false)
    }

    func updateState(hoveredEdge: ScreenEdge?, cursorLocalPoint: NSPoint?, animated: Bool = true) {
        self.hoveredEdge = hoveredEdge
        refreshGlowAppearance(animated: animated)
        updateBadge(for: hoveredEdge, cursorLocalPoint: cursorLocalPoint)
    }

    /// Plays a purely visual float-out animation where a ghost of the dropped file gently
    /// drifts past the screen boundary without touching the physical file on disk.
    func playFloatOutAnimation(
        image: NSImage,
        itemCount: Int,
        from edge: ScreenEdge,
        at localPoint: NSPoint,
        completion: @escaping @MainActor () -> Void
    ) {
        updateState(hoveredEdge: nil, cursorLocalPoint: nil, animated: true)

        let cardSize: CGFloat = 76
        let endSize: CGFloat = cardSize * 0.72
        let shrinkInset = (cardSize - endSize) / 2
        let startOrigin = floatStartOrigin(for: edge, localPoint: localPoint, cardSize: cardSize)
        let delta = floatExitDelta(for: edge, distance: 108)

        let ghostView = FloatOutFileView(
            image: image,
            itemCount: itemCount,
            accentColor: currentColor,
            frame: NSRect(origin: startOrigin, size: NSSize(width: cardSize, height: cardSize))
        )
        ghostView.alphaValue = 0.96
        addSubview(ghostView)

        let endFrame = NSRect(
            x: startOrigin.x + delta.dx + shrinkInset,
            y: startOrigin.y + delta.dy + shrinkInset,
            width: endSize,
            height: endSize
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.34
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.85, 0.36, 1.0)
            ghostView.animator().frame = endFrame
            ghostView.animator().alphaValue = 0.0
        } completionHandler: { [weak ghostView] in
            Task { @MainActor in
                ghostView?.removeFromSuperview()
                completion()
            }
        }
    }

    private func floatStartOrigin(for edge: ScreenEdge, localPoint: NSPoint, cardSize: CGFloat) -> NSPoint {
        let half = cardSize / 2
        let margin: CGFloat = 14
        switch edge {
        case .left:
            let y = min(max(localPoint.y - half, 40), bounds.height - cardSize - 40)
            return NSPoint(x: margin, y: y)
        case .right:
            let y = min(max(localPoint.y - half, 40), bounds.height - cardSize - 40)
            return NSPoint(x: bounds.width - cardSize - margin, y: y)
        case .top:
            let x = min(max(localPoint.x - half, 40), bounds.width - cardSize - 40)
            return NSPoint(x: x, y: bounds.height - cardSize - margin)
        }
    }

    private func floatExitDelta(for edge: ScreenEdge, distance: CGFloat) -> CGVector {
        switch edge {
        case .left:
            return CGVector(dx: -distance, dy: 8)
        case .right:
            return CGVector(dx: distance, dy: 8)
        case .top:
            return CGVector(dx: 0, dy: distance)
        }
    }

    // MARK: - Layer Setup

    private func setupLayers() {
        guard let rootLayer = layer else { return }

        for edge in ScreenEdge.allCases {
            let aura = makeGradientLayer(for: edge)
            let rim = makeGradientLayer(for: edge)

            if edge == .left || edge == .right {
                aura.mask = makeBottomFadeMask()
                rim.mask = makeBottomFadeMask()
            }

            rootLayer.addSublayer(aura)
            rootLayer.addSublayer(rim)
            auraLayers[edge] = aura
            rimLayers[edge] = rim
        }

        layoutEdgeLayers()
        refreshGlowAppearance(animated: false)
    }

    private func makeGradientLayer(for edge: ScreenEdge) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.locations = [0.0, 0.35, 1.0]

        // Standard non-flipped NSView uses bottom-left (0,0) -> top-right (1,1).
        switch edge {
        case .left:
            gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
        case .right:
            gradient.startPoint = CGPoint(x: 1.0, y: 0.5)
            gradient.endPoint = CGPoint(x: 0.0, y: 0.5)
        case .top:
            gradient.startPoint = CGPoint(x: 0.5, y: 1.0)
            gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
        }
        return gradient
    }

    private func makeBottomFadeMask() -> CAGradientLayer {
        let mask = CAGradientLayer()
        // Smoothly fade out near the bottom corner so the bottom edge remains unlit.
        mask.startPoint = CGPoint(x: 0.5, y: 0.0)
        mask.endPoint = CGPoint(x: 0.5, y: 1.0)
        mask.colors = [
            NSColor.clear.cgColor,
            NSColor.white.cgColor,
            NSColor.white.cgColor
        ]
        mask.locations = [0.0, 0.08, 1.0]
        return mask
    }

    private func layoutEdgeLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let rimThickness: CGFloat = 2.5

        for edge in ScreenEdge.allCases {
            let auraDepth: CGFloat = (hoveredEdge == edge) ? 58 : 34
            let auraFrame = frameForEdge(edge, depth: auraDepth)
            let rimFrame = frameForEdge(edge, depth: rimThickness)

            if let aura = auraLayers[edge] {
                aura.frame = auraFrame
                aura.mask?.frame = aura.bounds
            }
            if let rim = rimLayers[edge] {
                rim.frame = rimFrame
                rim.mask?.frame = rim.bounds
            }
        }

        CATransaction.commit()
    }

    private func frameForEdge(_ edge: ScreenEdge, depth: CGFloat) -> NSRect {
        switch edge {
        case .left:
            return NSRect(x: 0, y: 0, width: depth, height: bounds.height)
        case .right:
            return NSRect(x: bounds.width - depth, y: 0, width: depth, height: bounds.height)
        case .top:
            return NSRect(x: 0, y: bounds.height - depth, width: bounds.width, height: depth)
        }
    }

    private func refreshGlowAppearance(animated: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.16 : 0.0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

        for edge in ScreenEdge.allCases {
            let isHovered = (hoveredEdge == edge)
            let baseAlpha: CGFloat
            if let hoveredEdge {
                baseAlpha = (hoveredEdge == edge) ? hoveredAlpha : (idleAlpha * 0.55)
            } else {
                baseAlpha = idleAlpha
            }

            let auraDepth: CGFloat = isHovered ? 58 : 34
            if let aura = auraLayers[edge] {
                aura.frame = frameForEdge(edge, depth: auraDepth)
                aura.mask?.frame = aura.bounds
                aura.colors = [
                    currentColor.withAlphaComponent(baseAlpha * 0.65).cgColor,
                    currentColor.withAlphaComponent(baseAlpha * 0.24).cgColor,
                    currentColor.withAlphaComponent(0.0).cgColor
                ]
            }

            if let rim = rimLayers[edge] {
                let rimAlpha = isHovered ? min(1.0, baseAlpha + 0.1) : (baseAlpha * 0.85)
                rim.colors = [
                    currentColor.withAlphaComponent(rimAlpha).cgColor,
                    currentColor.withAlphaComponent(rimAlpha * 0.4).cgColor,
                    currentColor.withAlphaComponent(0.0).cgColor
                ]
            }
        }

        CATransaction.commit()
    }

    // MARK: - Hover Pill Badge

    private func setupBadgeView() {
        badgeView.alphaValue = 0
        badgeView.isHidden = true
        addSubview(badgeView)
    }

    private func updateBadge(for edge: ScreenEdge?, cursorLocalPoint: NSPoint?) {
        guard let edge else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                badgeView.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.hoveredEdge == nil else { return }
                    self.badgeView.isHidden = true
                }
            }
            return
        }

        badgeView.setAccentColor(currentColor)
        badgeView.layoutSubtreeIfNeeded()
        let pillFrame = edge.pillFrame(
            in: bounds,
            pillSize: badgeView.fittingSize,
            cursorLocalPoint: cursorLocalPoint
        )
        badgeView.frame = pillFrame
        badgeView.isHidden = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            badgeView.animator().alphaValue = 1
        }
    }
}

@MainActor
private final class EdgeBadgePillView: NSVisualEffectView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "AirDrop で送信")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 17
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iconView.image = NSImage(
            systemSymbolName: "dot.radiowaves.left.and.right",
            accessibilityDescription: "AirDrop"
        )?.withSymbolConfiguration(symbolConfig)
        iconView.contentTintColor = .white

        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    func setAccentColor(_ color: NSColor) {
        iconView.contentTintColor = color
        layer?.borderColor = color.withAlphaComponent(0.45).cgColor
    }
}

@MainActor
private final class FloatOutFileView: NSView {
    init(image: NSImage, itemCount: Int, accentColor: NSColor, frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.shadowColor = accentColor.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowRadius = 14
        layer?.shadowOffset = .zero

        let imageView = NSImageView(frame: bounds)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        if itemCount > 1 {
            let badge = NSTextField(labelWithString: "\(itemCount)")
            badge.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
            badge.textColor = .white
            badge.alignment = .center
            badge.autoresizingMask = [.minXMargin, .minYMargin]
            badge.wantsLayer = true
            badge.layer?.backgroundColor = accentColor.withAlphaComponent(0.95).cgColor
            badge.layer?.cornerRadius = 10
            badge.frame = NSRect(x: bounds.width - 24, y: bounds.height - 24, width: 22, height: 20)
            addSubview(badge)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
