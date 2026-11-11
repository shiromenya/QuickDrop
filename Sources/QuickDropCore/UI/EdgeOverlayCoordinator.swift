import AppKit

/// Manages ambient edge glow windows and edge drop panels across all connected displays.
@MainActor
final class EdgeOverlayCoordinator {
    var onDropCommitted: (() -> Void)?
    var onPayloadDropped: ((DraggedPayload, NSScreen?) -> Void)?

    private struct ScreenOverlay {
        let screen: NSScreen
        let glowWindow: AmbientGlowWindow
        let dropPanels: [ScreenEdge: EdgeDropPanel]
    }

    private let settings: QuickDropSettings
    private let previewProvider = FilePreviewProvider()
    private var overlays: [ScreenOverlay] = []
    private var isDraggingVisible = false
    private var isPlayingFloatOut = false
    private var hoveredTarget: (screenIndex: Int, edge: ScreenEdge)?
    private var overlayGeneration = 0

    init(settings: QuickDropSettings) {
        self.settings = settings
        rebuildOverlays()
    }

    func rebuildOverlays() {
        let wasVisible = isDraggingVisible
        tearDownOverlays()

        let allFrames = NSScreen.screens.map(\.frame)
        let hitThickness = settings.hitThicknessPreset.points

        overlays = NSScreen.screens.enumerated().map { index, screen in
            let activeEdges = ScreenEdge.activeEdges(
                for: screen.frame,
                allScreenFrames: allFrames,
                enabledEdges: settings.enabledEdges,
                excludeAdjacentScreenEdges: settings.excludeAdjacentScreenEdges
            )

            let glowWindow = AmbientGlowWindow(screenFrame: screen.frame)
            glowWindow.glowView.applyStyle(
                color: settings.colorPreset.primaryColor,
                intensity: settings.intensity,
                activeEdges: activeEdges
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
                panel.dropView.onPrefetchRequested = { [weak self] payload in
                    self?.previewProvider.prefetch(payload: payload)
                }
                panel.dropView.onHoverChanged = { [weak self] hoveredEdge, isHovered, globalCursor in
                    self?.handleHoverChanged(
                        screenIndex: index,
                        edge: hoveredEdge,
                        isHovered: isHovered,
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

    func updateCursorPosition(_ globalCursor: NSPoint) {
        guard isDraggingVisible, let hoveredTarget,
              overlays.indices.contains(hoveredTarget.screenIndex) else {
            return
        }
        let overlay = overlays[hoveredTarget.screenIndex]
        let localPoint = localPointInGlowView(globalCursor, overlay: overlay)
        overlay.glowWindow.glowView.updateState(
            hoveredEdge: hoveredTarget.edge,
            cursorLocalPoint: localPoint,
            animated: false
        )
    }

    // MARK: - Private

    private func showOverlays() {
        overlayGeneration += 1
        isDraggingVisible = true
        isPlayingFloatOut = false
        hoveredTarget = nil

        for overlay in overlays {
            overlay.glowWindow.glowView.updateState(
                hoveredEdge: nil,
                cursorLocalPoint: nil,
                animated: false
            )
            overlay.glowWindow.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                overlay.glowWindow.animator().alphaValue = 1
            }

            for panel in overlay.dropPanels.values {
                panel.dropView.isDropEnabled = true
                panel.ignoresMouseEvents = false
                panel.orderFrontRegardless()
            }
        }
    }

    private func hideOverlays() {
        overlayGeneration += 1
        isDraggingVisible = false
        hoveredTarget = nil
        previewProvider.clear()

        for overlay in overlays {
            disableDropPanels(in: overlay)
            fadeOutGlowWindow(overlay.glowWindow, generation: overlayGeneration)
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
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            glowWindow.animator().alphaValue = 0
        } completionHandler: { [weak self, weak glowWindow] in
            Task { @MainActor [weak self, weak glowWindow] in
                guard let self,
                      !self.isDraggingVisible,
                      self.overlayGeneration == generation else {
                    return
                }
                glowWindow?.orderOut(nil)
            }
        }
    }

    private func handleHoverChanged(
        screenIndex: Int,
        edge: ScreenEdge,
        isHovered: Bool,
        globalCursor: NSPoint?
    ) {
        guard isDraggingVisible, overlays.indices.contains(screenIndex) else { return }

        let previousTarget = hoveredTarget
        if isHovered {
            hoveredTarget = (screenIndex, edge)
            if settings.hapticFeedbackEnabled,
               previousTarget?.screenIndex != screenIndex || previousTarget?.edge != edge {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        } else if let current = hoveredTarget,
                  current.screenIndex == screenIndex && current.edge == edge {
            hoveredTarget = nil
        }

        for (idx, overlay) in overlays.enumerated() {
            if let target = hoveredTarget, target.screenIndex == idx {
                let localPoint = globalCursor.map { localPointInGlowView($0, overlay: overlay) }
                overlay.glowWindow.glowView.updateState(
                    hoveredEdge: target.edge,
                    cursorLocalPoint: localPoint,
                    animated: true
                )
            } else {
                overlay.glowWindow.glowView.updateState(
                    hoveredEdge: nil,
                    cursorLocalPoint: nil,
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
        isPlayingFloatOut = true
        hoveredTarget = nil
        onDropCommitted?()

        let previewImage = previewProvider.previewImage(for: payload)
        previewProvider.clear()

        for (idx, overlay) in overlays.enumerated() {
            disableDropPanels(in: overlay)
            if idx != screenIndex {
                fadeOutGlowWindow(overlay.glowWindow, generation: activeGeneration)
            }
        }

        guard overlays.indices.contains(screenIndex) else {
            isPlayingFloatOut = false
            onPayloadDropped?(payload, nil)
            return
        }

        let targetOverlay = overlays[screenIndex]
        let localPoint = localPointInGlowView(dropPoint, overlay: targetOverlay)

        // Start the ghost float-out animation immediately at the drop coordinate, then launch
        // the AirDrop picker just as the item fades past the screen edge.
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
            self.onPayloadDropped?(payload, screen)
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
