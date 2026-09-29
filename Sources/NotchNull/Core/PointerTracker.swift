import AppKit

/// App-wide mouse observation. Global monitors cover other apps' windows, local monitors cover ours.
/// Mouse-move and drag monitoring needs no Accessibility permission.
@MainActor
final class PointerTracker {
    static let shared = PointerTracker()

    struct Handlers {
        var moved: (NSPoint) -> Void
        var dragged: (NSPoint, _ hasFileDrag: Bool) -> Void
        var mouseUp: (NSPoint) -> Void
        var scrolled: (NSEvent) -> Void
    }

    private var handlers: [ObjectIdentifier: Handlers] = [:]
    private var monitors: [Any] = []
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount

    func register(_ owner: AnyObject, handlers: Handlers) {
        self.handlers[ObjectIdentifier(owner)] = handlers
        if monitors.isEmpty { install() }
    }

    func unregister(_ owner: AnyObject) {
        handlers[ObjectIdentifier(owner)] = nil
    }

    private func install() {
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp, .scrollWheel]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moveMask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moveMask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            dragChangeCount = NSPasteboard(name: .drag).changeCount
        case .leftMouseDragged:
            let hasDrag = NSPasteboard(name: .drag).changeCount != dragChangeCount
            handlers.values.forEach { $0.dragged(location, hasDrag) }
        case .leftMouseUp:
            handlers.values.forEach { $0.mouseUp(location) }
        case .scrollWheel:
            handlers.values.forEach { $0.scrolled(event) }
        default:
            handlers.values.forEach { $0.moved(location) }
        }
    }
}
