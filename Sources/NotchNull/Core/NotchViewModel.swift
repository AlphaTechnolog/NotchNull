import AppKit
import Combine
import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case home, agents, controls, tray, clipboard, mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .agents: "Agents"
        case .controls: "Controls"
        case .tray: "Tray"
        case .clipboard: "Clipboard"
        case .mirror: "Mirror"
        }
    }

    var symbol: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .agents: "sparkle"
        case .controls: "switch.2"
        case .tray: "tray.full.fill"
        case .clipboard: "list.clipboard.fill"
        case .mirror: "web.camera.fill"
        }
    }
}

/// Per-screen presentation state: one body morphing out of the hardware notch.
@MainActor
final class NotchViewModel: ObservableObject {
    enum Phase: Equatable {
        case closed
        case activity(ActivityKind)
        case open
        case drop
    }

    let geometry: NotchGeometry

    @Published private(set) var phase: Phase = .closed
    @Published var selectedTab: NotchTab = .home
    @Published var isPointerInside = false
    /// Direction of the last tab change, used for the directional content slide.
    @Published private(set) var tabDirection: Edge = .trailing

    private var isOpen = false
    private var isDropping = false
    private var activity: ActivityKind?
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []
    private let preferences = Preferences.shared

    convenience init(geometry: NotchGeometry) {
        self.init(geometry: geometry, center: ActivityCenter.shared)
    }

    init(geometry: NotchGeometry, center: ActivityCenter) {
        self.geometry = geometry
        center.$current
            .receive(on: RunLoop.main)
            .sink { [weak self] kind in self?.activityChanged(kind) }
            .store(in: &cancellables)
        // Size preferences change the body live.
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }
            .store(in: &cancellables)
    }

    // MARK: Geometry

    /// The hardware notch (or the virtual one on displays without a notch).
    var notchSize: CGSize { geometry.notchSize }

    /// The closed body: the hardware notch plus the user's extra width. It can only grow,
    /// because nothing can be drawn over the camera housing.
    var closedSize: CGSize {
        CGSize(width: notchSize.width + CGFloat(preferences.closedExtraWidth), height: notchSize.height)
    }

    var panelContentHeight: CGFloat { CGFloat(preferences.panelHeight) }
    var panelWidth: CGFloat { max(CGFloat(preferences.panelWidth), closedSize.width + 120) }

    var bodySize: CGSize {
        switch phase {
        case .closed:
            return closedSize
        case .open:
            return CGSize(width: panelWidth, height: notchSize.height + panelContentHeight)
        case .drop:
            return CGSize(width: panelWidth, height: notchSize.height + Theme.Size.dropContentHeight)
        case .activity(let kind):
            let layout = kind.layout
            let scale = CGFloat(preferences.activityWidthScale)
            // Wings hug their content: measured width + a small gap to the camera + the outer padding.
            let wing = measuredWings[kind].map { $0 + Self.wingInnerGap + Self.wingOuterPadding } ?? layout.wing
            let width = max(closedSize.width + wing * 2 * scale, layout.minWidth * scale, closedSize.width + 40)
            return CGSize(width: width, height: notchSize.height + layout.extraHeight)
        }
    }

    static let wingInnerGap: CGFloat = 8
    static let wingOuterPadding: CGFloat = 12

    /// Widest wing content measured per activity, so each wing is only as wide as what it shows.
    @Published private(set) var measuredWings: [ActivityKind: CGFloat] = [:]

    func reportWingContent(_ width: CGFloat, for kind: ActivityKind) {
        let rounded = ceil(width)
        guard rounded > 0, abs((measuredWings[kind] ?? 0) - rounded) > 1 else { return }
        withAnimation(Motion.value) { measuredWings[kind] = rounded }
    }

    var topRadius: CGFloat {
        switch phase {
        case .closed: Theme.Radius.closedTop
        case .activity(let kind): kind.layout.extraHeight > 0 ? Theme.Radius.openTop * 0.8 : Theme.Radius.closedTop
        case .open, .drop: Theme.Radius.openTop
        }
    }

    var bottomRadius: CGFloat {
        let scale = CGFloat(preferences.cornerScale)
        switch phase {
        case .closed: return Theme.Radius.closedBottom
        case .activity(let kind): return (kind.layout.extraHeight > 0 ? Theme.Radius.openBottom * 0.75 : Theme.Radius.compactBottom) * scale
        case .open, .drop: return Theme.Radius.openBottom * scale
        }
    }

    /// The shape is drawn wider than the body by the top flare on both sides.
    var shapeSize: CGSize {
        CGSize(width: bodySize.width + topRadius * 2, height: bodySize.height)
    }

    /// Screen-space rect that counts as "on the notch" for hover and clicks.
    var interactiveRect: CGRect {
        let body = geometry.bodyRect(for: shapeSize)
        switch phase {
        case .closed:
            return geometry.bodyRect(for: closedSize).insetBy(dx: -14, dy: 0).offsetBy(dx: 0, dy: -2)
        case .activity(let kind) where !kind.layout.interactive:
            return body.insetBy(dx: -6, dy: 0)
        default:
            return body.insetBy(dx: -4, dy: -4)
        }
    }

    /// Rect a file drag must reach to turn the notch into a drop target.
    var dropProximityRect: CGRect {
        let size = CGSize(width: panelWidth + 80, height: notchSize.height + Theme.Size.dropContentHeight + 60)
        return geometry.bodyRect(for: size)
    }

    var isExpanded: Bool { phase == .open || phase == .drop }

    // MARK: Pointer

    /// Returns whether the pointer is over the notch (the window stops passing clicks through).
    @discardableResult
    func pointerMoved(to point: CGPoint) -> Bool {
        let inside = interactiveRect.contains(point)
        guard inside != isPointerInside else { return inside }
        isPointerInside = inside
        Log.window.debug("Pointer \(inside ? "entered" : "left") notch, phase=\(String(describing: self.phase), privacy: .public)")
        if inside {
            closeWork?.cancel()
            guard !isOpen, preferences.openTrigger == .hover else { return inside }
            if case .activity(let kind) = phase, kind.layout.interactive { return inside }
            schedule(&openWork, after: Motion.hoverOpenDelay) { [weak self] in self?.open() }
        } else {
            openWork?.cancel()
            guard isOpen, !isDropping else { return inside }
            schedule(&closeWork, after: Motion.hoverCloseDelay) { [weak self] in self?.close() }
        }
        return inside
    }

    // MARK: Transitions

    func open(tab: NotchTab? = nil) {
        openWork?.cancel()
        closeWork?.cancel()
        if let tab { select(tab) }
        guard !isOpen else { return }
        isOpen = true
        if preferences.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        if activity == .needsYou { selectedTab = .agents }
        apply(Motion.open)
    }

    func close() {
        openWork?.cancel()
        closeWork?.cancel()
        guard isOpen else { return }
        isOpen = false
        apply(Motion.close)
    }

    func toggle() { isOpen ? close() : open() }

    func beginDrop() {
        guard !isDropping else { return }
        isDropping = true
        closeWork?.cancel()
        apply(Motion.open)
    }

    func endDrop() {
        guard isDropping else { return }
        isDropping = false
        if isOpen && !isPointerInside { isOpen = false }
        apply(Motion.close)
    }

    func select(_ tab: NotchTab) {
        guard tab != selectedTab else { return }
        let all = preferences.orderedTabs
        let forward = (all.firstIndex(of: tab) ?? 0) > (all.firstIndex(of: selectedTab) ?? 0)
        tabDirection = forward ? .trailing : .leading
        withAnimation(Motion.state) { selectedTab = tab }
    }

    /// Fixture entry point for snapshot rendering.
    func preview(phase: Phase, tab: NotchTab = .home) {
        self.phase = phase
        selectedTab = tab
    }

    private func activityChanged(_ kind: ActivityKind?) {
        activity = kind
        apply(kind != nil ? Motion.activity : Motion.close)
    }

    private func apply(_ animation: Animation) {
        let next: Phase
        if isDropping {
            next = .drop
        } else if isOpen {
            next = .open
        } else if let activity {
            next = .activity(activity)
        } else {
            next = .closed
        }
        guard next != phase else { return }
        withAnimation(animation) { phase = next }
    }

    private func schedule(_ slot: inout DispatchWorkItem?, after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        slot?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { action() } }
        slot = work
        if delay <= 0 {
            DispatchQueue.main.async(execute: work)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }
}
