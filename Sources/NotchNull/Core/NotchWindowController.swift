import AppKit
import Combine
import SwiftUI

/// Owns one notch panel on one screen: positions it, routes pointer input and keeps
/// click-through outside the visible pieces.
@MainActor
final class NotchWindowController {
    let model: NotchViewModel
    private let panel: NotchPanel
    private var cancellables: Set<AnyCancellable> = []
    private var dropArmed = false
    private var scrollAccumulator: CGFloat = 0

    init(screen: NSScreen, services: AppServices) {
        let geometry = NotchGeometry(screen: screen)
        model = NotchViewModel(geometry: geometry)
        panel = NotchPanel(frame: geometry.windowFrame)

        let root = NotchRootView()
            .environmentObject(model)
            .withServices(services)
        panel.contentView = NotchHostingView(rootView: AnyView(root))
        panel.setFrame(geometry.windowFrame, display: false)
        panel.orderFrontRegardless()

        PointerTracker.shared.register(self, handlers: .init(
            moved: { [weak self] point in self?.pointerMoved(point) },
            dragged: { [weak self] point, hasDrag in self?.pointerDragged(point, hasFileDrag: hasDrag) },
            mouseUp: { [weak self] point in self?.pointerReleased(point) },
            scrolled: { [weak self] event in self?.scrolled(event) }
        ))

        model.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refreshHitTesting() } }
            .store(in: &cancellables)
        Log.window.info("Notch panel on screen \(NotchGeometry.screenID(screen)) notch=\(geometry.notchSize.width)x\(geometry.notchSize.height) hardware=\(geometry.hasHardwareNotch)")
    }

    func tearDown() {
        PointerTracker.shared.unregister(self)
        panel.orderOut(nil)
        panel.close()
    }

    private func pointerMoved(_ point: NSPoint) {
        guard !dropArmed else { return }
        panel.ignoresMouseEvents = !model.pointerMoved(to: point)
    }

    private func pointerDragged(_ point: NSPoint, hasFileDrag: Bool) {
        guard hasFileDrag, Preferences.shared.trayEnabled else { return }
        let near = model.dropProximityRect.contains(point)
        if near && !dropArmed {
            dropArmed = true
            panel.ignoresMouseEvents = false
            model.beginDrop()
        } else if !near && dropArmed {
            dropArmed = false
            model.endDrop()
            refreshHitTesting()
        }
    }

    private func pointerReleased(_ point: NSPoint) {
        guard dropArmed else { return }
        dropArmed = false
        // Give SwiftUI's drop handler a beat to receive the payload before the tiles collapse.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.model.endDrop()
            self.refreshHitTesting()
        }
    }

    private func scrolled(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        guard model.interactiveRect.contains(location) else { return }
        if event.phase == .began { scrollAccumulator = 0 }
        let delta = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        scrollAccumulator += delta
        let threshold: CGFloat = 18
        if !model.isExpanded, scrollAccumulator > threshold {
            scrollAccumulator = 0
            model.open()
        } else if model.phase == .open, scrollAccumulator < -threshold * 2,
                  location.y > model.geometry.screenFrame.maxY - model.notchSize.height - Theme.Size.headerHeight - 16 {
            scrollAccumulator = 0
            model.close()
        }
    }

    private func refreshHitTesting() {
        guard !dropArmed else { return }
        panel.ignoresMouseEvents = !model.pointerMoved(to: NSEvent.mouseLocation)
    }
}
