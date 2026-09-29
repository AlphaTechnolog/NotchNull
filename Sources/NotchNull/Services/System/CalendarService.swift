import AppKit
import Combine
import EventKit
import SwiftUI

struct UpcomingEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarColor: Color
    let meetingURL: URL?
    let location: String?

    var isOngoing: Bool { start <= Date() && end > Date() }
}

/// Next calendar events with meeting-link detection, and a "starting soon" peek.
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [UpcomingEvent] = []
    @Published private(set) var access: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()
    private var timer: Timer?
    private var announced: Set<String> = []
    private var observer: NSObjectProtocol?

    var next: UpcomingEvent? { events.first }

    func start() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ events: [UpcomingEvent]) {
        self.events = events
        access = .fullAccess
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            access = EKEventStore.authorizationStatus(for: .event)
            refresh()
        }
    }

    func refresh() {
        access = EKEventStore.authorizationStatus(for: .event)
        guard Preferences.shared.calendarEnabled, access == .fullAccess else {
            events = []
            ActivityCenter.shared.setPersistent(.meetingSoon, active: false)
            return
        }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: now.addingTimeInterval(24 * 3600), calendars: nil)
        let found = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { event in
                UpcomingEvent(
                    id: event.calendarItemIdentifier + "\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "Event",
                    start: event.startDate,
                    end: event.endDate,
                    calendarColor: Color(nsColor: event.calendar?.color ?? .systemRed),
                    meetingURL: Self.meetingURL(in: event),
                    location: event.location
                )
            }
        let list = Array(found)
        if list != events { withAnimation(Motion.state) { events = list } }
        updateSoon()
    }

    private func updateSoon() {
        let now = Date()
        let soon = events.first { $0.start > now && $0.start.timeIntervalSince(now) <= Constants.Durations.meetingLead }
        ActivityCenter.shared.setPersistent(.meetingSoon, active: soon != nil)
        if let soon, !announced.contains(soon.id) {
            announced.insert(soon.id)
            if Preferences.shared.sounds { NSSound(named: "Tink")?.play() }
            ActivityLog.shared.add(symbol: "video.fill", tint: Theme.Accent.calendar, title: soon.title, detail: "Starts \(soon.start.formatted(date: .omitted, time: .shortened))", action: soon.meetingURL.map { .open($0) })
        }
    }

    func join(_ event: UpcomingEvent) {
        guard let url = event.meetingURL else { return }
        NSWorkspace.shared.open(url)
        ActivityCenter.shared.setPersistent(.meetingSoon, active: false)
    }

    private static func meetingURL(in event: EKEvent) -> URL? {
        let candidates = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in candidates {
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let url = match.url, let host = url.host?.lowercased() else { continue }
                if Constants.Meeting.hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}
