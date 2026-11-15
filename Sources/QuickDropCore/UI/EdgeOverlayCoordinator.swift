import AppKit

/// Manages ambient edge glow windows and edge drop panels across all connected displays.
@MainActor
final class EdgeOverlayCoordinator {
    var onDropCommitted: (() -> Void)?
    var onPayloadDropped: ((DraggedPayload, ShareBehavior, Bool, NSScreen?) -> Void)?

    private struct ScreenOverlay {
        let screen: NSScreen
        let glowWindow: AmbientGlowWindow
        let dropPanels: [ScreenEdge: EdgeDropPanel]
    }

    private let settings: QuickDropSettings
    private let previewProvider = FilePreviewProvider()
    private var overlays: [ScreenOverlay] = []
    private var isDraggingVisible = false
    private var isPreviewVisible = false
    private var isPlayingFloatOut = false
    private var hoveredTarget: (screenIndex: Int, edge: ScreenEdge, phase: EdgeHoverPhase)?
    private var focusedScreenIndex: Int?
    private var overlayGeneration = 0
    private var previewTask: Task<Void, Never>?

    init(settings: QuickDropSettings) {
        self.settings = settings
        rebuildOverlays()
    }

    func rebuildOverlays() {
        let wasVisible = isDraggingVisible
        previewTask?.cancel()
        previewTask = nil
        isPreviewVisible = false
        tearDownOverlays()

        let allScreens = NSScreen.screens
        let allFrames = allScreens.map(\.frame)
        let enabledScreens = allScreens.filter { settings.isDisplayEnabled($0.quickDropDisplayID) }
        let hitThickness = settings.hitThicknessPreset.points
        let hoverDelay = settings.hoverDelayPreset.seconds

        let edgeBehaviors = Dictionary(
            uniqueKeysWithValues: ScreenEdge.allCases.map { ($0, settings.resolvedShareBehavior(for: $0)) }
        )

        overlays = enabledScreens.enumerated().map { index, screen in
            let activeEdges = ScreenEdge.activeEdges(
                for: screen.frame,
                allScreenFrames: allFrames,
                enabledEdges: settings.enabledEdges,
                excludeAdjacentScreenEdges: settings.excludeAdjacentScreenEdges
            )

            let glowWindow = AmbientGlowWindow(screenFrame: screen.frame)
            glowWindow.glowView.applyStyle(
                color: settings.activeGlowColor,
                intensity: settings.intensity,
                activeEdges: activeEdges,
                shareBehavior: settings.shareBehavior,
                edgeShareBehaviors: edgeBehaviors
            )

            var panels: [ScreenEdge: EdgeDropPanel] = [:]
            for edge in activeEdges {
                let rect = edge.dropRect(
                    in: screen.frame,
                    hitThickness: hitThickness,
                    cornerInset: settings.cornerInset
                )
                let panel = EdgeDropPanel(edge: edge, frame: rect)
                panel.dropView.allowWebAndImageDrags = settings.allowWebAndImageDrags
                panel.dropView.hoverDelay = hoverDelay
                panel.dropView.onPrefetchRequested = { [weak self] payload in
                    self?.previewProvider.prefetch(payload: payload)
                }
                panel.dropView.onHoverPhaseChanged = { [weak self] hoveredEdge, phase, globalCursor in
                    self?.handleHoverPhaseChanged(
                        screenIndex: index,
                        edge: hoveredEdge,
                        phase: phase,
                        globalCursor: globalCursor
                    )
                }
                panel.dropView.onFilesDropped = { [weak self] payload, droppedEdge, dropPoint in
                    self?.handlePayloadDropped(
                        payload,
                        edge: droppedEdge,
                        dropPoint: dropPoint,
                        screenIndex: index
                    )
                }
                panels[edge] = panel
            }

            return ScreenOverlay(screen: screen, glowWindow: glowWindow, dropPanels: panels)
        }

        if wasVisible {
            showOverlays()
        }
    }

    func applySettings() {
        rebuildOverlays()
    }

    func setDraggingActive(_ active: Bool) {
        if active {
            showOverlays()
        } else if !isPlayingFloatOut {
            hideOverlays()
        }
    }

    func showPreviewGlow(duration: TimeInterval = 2.2) {
        guard !isDraggingVisible, !isPlayingFloatOut else { return }

        guard !overlays.isEmpty, !settings.enabledEdges.isEmpty else {
            ToastHUDPresenter.shared.show(
                message: L10n.tr("toast.no_active_edges"),
                style: .info,
                on: NSScreen.main
            )
            return
        }

        previewTask?.cancel()
        overlayGeneration += 1
        let activeGeneration = overlayGeneration
        isPreviewVisible = true

        let fadeDuration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.08 : 0.18
        for overlay in overlays {
            disableDropPanels(in: overlay)
            overlay.glowWindow.glowView.updateState(
                hoveredEdge: nil,
                cursorLocalPoint: nil,
                animated: false
            )
            overlay.glowWindow.glowView.setPreviewHighlighted(true, animated: true)
            overlay.glowWindow.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeDuration
                overlay.glowWindow.animator().alphaValue = 1
            }
        }

        previewTask = Task { [weak self] in
            let nanos = UInt64(max(0.4, duration) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            self?.dismissPreviewGlowIfNeeded(expectedGeneration: activeGeneration)
        }
    }

    func updateCursorPosition(_ globalCursor: NSPoint) {
        guard isDraggingVisible else { return }

        if settings.displayGlowScope == .cursorDisplayOnly, hoveredTarget == nil {
            let nextIndex = ScreenEdge.screenIndex(
                for: globalCursor,
                in: overlays.map(\.screen.frame)
            )
            if nextIndex != focusedScreenIndex {
                focusedScreenIndex = nextIndex
                syncFocusedScreenVisibility()
            }
        }

        let shiftPressed = NSEvent.modifierFlags.contains(.shift)
        guard let hoveredTarget, overlays.indices.contains(hoveredTarget.screenIndex) else {
            for overlay in overlays {
                overlay.glowWindow.glowView.updateShiftPressed(shiftPressed)
            }
            return
        }
        let overlay = overlays[hoveredTarget.screenIndex]
        let localPoint = localPointInGlowView(globalCursor, overlay: overlay)
        let isArmed = hoveredTarget.phase == .armed
        overlay.glowWindow.glowView.updateState(
            hoveredEdge: isArmed ? hoveredTarget.edge : nil,
            warmingUpEdge: isArmed ? nil : hoveredTarget.edge,
            cursorLocalPoint: localPoint,
            shiftPressed: shiftPressed,
            animated: false
        )
    }

    // MARK: - Private

    private func showOverlays() {
        previewTask?.cancel()
        previewTask = nil
        isPreviewVisible = false
        overlayGeneration += 1
        isDraggingVisible = true
        isPlayingFloatOut = false
        hoveredTarget = nil
        focusedScreenIndex = settings.displayGlowScope == .cursorDisplayOnly
            ? ScreenEdge.screenIndex(for: NSEvent.mouseLocation, in: overlays.map(\.screen.frame))
            : nil

        for (idx, overlay) in overlays.enumerated() {
            overlay.glowWindow.glowView.setPreviewHighlighted(false, animated: false)
            overlay.glowWindow.glowView.updateState(
                hoveredEdge: nil,
                cursorLocalPoint: nil,
                animated: false
            )
            let isVisibleOnDisplay = shouldOverlayDisplay(at: idx)
            setOverlay(overlay, activeForDrag: isVisibleOnDisplay, generation: overlayGeneration)
        }
    }

    private func hideOverlays() {
        previewTask?.cancel()
        previewTask = nil
        isPreviewVisible = false
        focusedScreenIndex = nil
        overlayGeneration += 1
        isDraggingVisible = false
        hoveredTarget = nil
        previewProvider.clear()

        for overlay in overlays {
            overlay.glowWindow.glowView.setPreviewHighlighted(false, animated: false)
            disableDropPanels(in: overlay)
            fadeOutGlowWindow(overlay.glowWindow, generation: overlayGeneration)
        }
    }

    private func dismissPreviewGlowIfNeeded(expectedGeneration: Int) {
        guard isPreviewVisible,
              !isDraggingVisible,
              !isPlayingFloatOut,
              overlayGeneration == expectedGeneration else {
            return
        }
        isPreviewVisible = false
        overlayGeneration += 1
        let fadeGeneration = overlayGeneration
        for overlay in overlays {
            overlay.glowWindow.glowView.setPreviewHighlighted(false, animated: true)
            fadeOutGlowWindow(overlay.glowWindow, generation: fadeGeneration)
        }
    }

    private func shouldOverlayDisplay(at index: Int) -> Bool {
        switch settings.displayGlowScope {
        case .allDisplays:
            return true
        case .cursorDisplayOnly:
            return focusedScreenIndex == nil || focusedScreenIndex == index
        }
    }

    private func syncFocusedScreenVisibility() {
        for (idx, overlay) in overlays.enumerated() {
            let isVisibleOnDisplay = shouldOverlayDisplay(at: idx)
            setOverlay(overlay, activeForDrag: isVisibleOnDisplay, generation: overlayGeneration)
        }
    }

    private func setOverlay(_ overlay: ScreenOverlay, activeForDrag: Bool, generation: Int) {
        let fadeDuration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.08 : 0.16
        if activeForDrag {
            overlay.glowWindow.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeDuration
                overlay.glowWindow.animator().alphaValue = 1
            }
            for panel in overlay.dropPanels.values {
                panel.dropView.isDropEnabled = true
                panel.ignoresMouseEvents = false
                panel.orderFrontRegardless()
            }
        } else {
            disableDropPanels(in: overlay)
            fadeOutGlowWindow(overlay.glowWindow, generation: generation)
        }
    }

    private func disableDropPanels(in overlay: ScreenOverlay) {
        for panel in overlay.dropPanels.values {
            panel.dropView.isDropEnabled = false
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }

    private func fadeOutGlowWindow(_ glowWindow: AmbientGlowWindow, generation: Int) {
        glowWindow.glowView.updateState(
            hoveredEdge: nil,
            cursorLocalPoint: nil,
            animated: true
        )
        let fadeDuration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.08 : 0.15
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            glowWindow.animator().alphaValue = 0
        } completionHandler: { [weak self, weak glowWindow] in
            Task { @MainActor [weak self, weak glowWindow] in
                guard let self,
                      !self.isDraggingVisible,
                      !self.isPreviewVisible,
                      self.overlayGeneration == generation else {
                    return
                }
                glowWindow?.orderOut(nil)
            }
        }
    }

    private func handleHoverPhaseChanged(
        screenIndex: Int,
        edge: ScreenEdge,
        phase: EdgeHoverPhase,
        globalCursor: NSPoint?
    ) {
        guard isDraggingVisible, overlays.indices.contains(screenIndex) else { return }

        let previousTarget = hoveredTarget
        if phase == .none {
            if let current = hoveredTarget,
               current.screenIndex == screenIndex && current.edge == edge {
                hoveredTarget = nil
            }
        } else {
            hoveredTarget = (screenIndex, edge, phase)
            if settings.hapticFeedbackEnabled,
               phase == .armed,
               (previousTarget?.screenIndex != screenIndex ||
                previousTarget?.edge != edge ||
                previousTarget?.phase != .armed) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }

        let shiftPressed = NSEvent.modifierFlags.contains(.shift)
        for (idx, overlay) in overlays.enumerated() {
            if let target = hoveredTarget, target.screenIndex == idx {
                let localPoint = globalCursor.map { localPointInGlowView($0, overlay: overlay) }
                let isArmed = target.phase == .armed
                overlay.glowWindow.glowView.updateState(
                    hoveredEdge: isArmed ? target.edge : nil,
                    warmingUpEdge: isArmed ? nil : target.edge,
                    cursorLocalPoint: localPoint,
                    shiftPressed: shiftPressed,
                    animated: true
                )
            } else {
                overlay.glowWindow.glowView.updateState(
                    hoveredEdge: nil,
                    warmingUpEdge: nil,
                    cursorLocalPoint: nil,
                    shiftPressed: shiftPressed,
                    animated: true
                )
            }
        }
    }

    private func handlePayloadDropped(
        _ payload: DraggedPayload,
        edge: ScreenEdge,
        dropPoint: NSPoint,
        screenIndex: Int
    ) {
        overlayGeneration += 1
        let activeGeneration = overlayGeneration
        isDraggingVisible = false
        isPreviewVisible = false
        isPlayingFloatOut = true
        hoveredTarget = nil
        focusedScreenIndex = nil
        if settings.soundFeedbackEnabled {
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
        onDropCommitted?()

        let previewImage = previewProvider.previewImage(for: payload)
        previewProvider.clear()

        for (idx, overlay) in overlays.enumerated() {
            disableDropPanels(in: overlay)
            if idx != screenIndex {
                fadeOutGlowWindow(overlay.glowWindow, generation: activeGeneration)
            }
        }

        let resolvedBehavior = settings.resolvedShareBehavior(for: edge)
        let shiftPressed = NSEvent.modifierFlags.contains(.shift)

        guard overlays.indices.contains(screenIndex) else {
            isPlayingFloatOut = false
            onPayloadDropped?(payload, resolvedBehavior, shiftPressed, nil)
            return
        }

        let targetOverlay = overlays[screenIndex]
        let localPoint = localPointInGlowView(dropPoint, overlay: targetOverlay)

        // Start the ghost float-out animation (and drop ripple when motion is enabled) immediately
        // at the drop coordinate, then launch the AirDrop picker just as the item fades past the edge.
        targetOverlay.glowWindow.glowView.playFloatOutAnimation(
            image: previewImage,
            itemCount: payload.itemCount,
            from: edge,
            at: localPoint
        ) { [weak self, weak glowWindow = targetOverlay.glowWindow] in
            guard let self,
                  !self.isDraggingVisible,
                  self.overlayGeneration == activeGeneration,
                  let glowWindow else {
                return
            }
            self.isPlayingFloatOut = false
            self.fadeOutGlowWindow(glowWindow, generation: activeGeneration)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self, weak screen = targetOverlay.screen] in
            guard let self, self.overlayGeneration == activeGeneration else { return }
            self.onPayloadDropped?(payload, resolvedBehavior, shiftPressed, screen)
        }
    }

    private func localPointInGlowView(_ globalPoint: NSPoint, overlay: ScreenOverlay) -> NSPoint {
        let frame = overlay.screen.frame
        return NSPoint(
            x: globalPoint.x - frame.minX,
            y: globalPoint.y - frame.minY
        )
    }

    private func tearDownOverlays() {
        for overlay in overlays {
            for panel in overlay.dropPanels.values {
                panel.dropView.isDropEnabled = false
                panel.orderOut(nil)
                panel.close()
            }
            overlay.glowWindow.orderOut(nil)
            overlay.glowWindow.close()
        }
        overlays.removeAll()
    }
}
