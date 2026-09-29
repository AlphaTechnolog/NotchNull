import SwiftUI

struct BatteryGlyph: View {
    var percent: Int
    var tint: Color
    var charging: Bool

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: max(2, 21 * CGFloat(percent) / 100))
                    .padding(2)
                    .animation(Motion.value, value: percent)
            }
            .frame(width: 26, height: 12.5)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white.opacity(0.4))
                .frame(width: 1.5, height: 4.5)
        }
        .accessibilityHidden(true)
    }
}

struct ChargingActivity: View {
    @EnvironmentObject private var battery: BatteryService
    @State private var bounce = false

    var body: some View {
        let state = battery.state
        WingsLayout {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(state.chargeTint)
                .symbolEffect(.bounce, value: bounce)
        } trailing: {
            HStack(spacing: 6) {
                BatteryGlyph(percent: state.percent, tint: state.chargeTint, charging: true)
                Text("\(state.percent)%")
                    .font(Theme.Typeface.wing)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .onAppear { bounce.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Charging, \(state.percent) percent")
    }
}

struct LowBatteryActivity: View {
    @EnvironmentObject private var battery: BatteryService

    var body: some View {
        let state = battery.state
        WingsLayout {
            Image(systemName: "battery.25percent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Accent.danger)
                .symbolEffect(.pulse, options: .repeating)
        } trailing: {
            Text("\(state.percent)%")
                .font(Theme.Typeface.wing)
                .foregroundStyle(Theme.Accent.danger)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery low, \(state.percent) percent")
    }
}

/// A device connected, disconnected or something arrived: the device icon with a small change
/// badge and its name on the left; battery levels, a port, a file or the change on the right.
struct AccessoryActivity: View {
    @EnvironmentObject private var devices: DeviceEvents

    var body: some View {
        let event = devices.last
        WingsLayout {
            HStack(spacing: 7) {
                Image(systemName: event?.symbol ?? "cable.connector")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(event?.change == .disconnected ? Theme.Palette.textSecondary : .white)
                    .symbolEffect(.bounce, value: event?.id)
                    .frame(width: 22)
                    .overlay(alignment: .bottomTrailing) {
                        if let event { ChangeBadge(change: event.change).offset(x: 4, y: 4) }
                    }
                Text(event?.name ?? "Device")
                    .font(Theme.Typeface.bodyStrong)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)
            }
        } trailing: {
            HStack(spacing: 8) {
                if let info = event?.accessory {
                    if let left = info.left { BudLevel(side: "L", value: left) }
                    if let right = info.right { BudLevel(side: "R", value: right) }
                    if info.left == nil, info.right == nil, let single = info.single { BudLevel(side: nil, value: single) }
                } else if let event {
                    Text(event.detail ?? event.change.label)
                        .font(event.detail?.hasPrefix("/dev/") == true ? Theme.Typeface.caption.monospaced() : Theme.Typeface.label)
                        .foregroundStyle(event.change == .disconnected ? Theme.Palette.textTertiary : Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 170, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.map { "\($0.name) \($0.change.label.lowercased())\($0.detail.map { ", \($0)" } ?? "")" } ?? "Device")
    }
}

/// Plus, minus or arrow in the event's color, pinned to the device icon.
private struct ChangeBadge: View {
    let change: DeviceEvent.Change

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(.black)
            .frame(width: 11, height: 11)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(.black, lineWidth: 1.5))
    }

    private var symbol: String {
        switch change {
        case .connected: "plus"
        case .disconnected: "minus"
        case .received: "arrow.down"
        }
    }

    private var color: Color {
        switch change {
        case .connected: Theme.Accent.success
        case .disconnected: Theme.Palette.textSecondary
        case .received: Theme.Accent.airdrop
        }
    }
}

private struct BudLevel: View {
    let side: String?
    let value: Int

    var body: some View {
        HStack(spacing: 3) {
            if let side {
                Text(side).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.textTertiary)
            }
            Text("\(value)%")
                .font(Theme.Typeface.metric)
                .foregroundStyle(value <= 20 ? Theme.Accent.danger : Theme.Palette.textPrimary)
        }
    }
}

struct TimerActivity: View {
    @EnvironmentObject private var timer: TimerService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            WingsLayout {
                RingGauge(progress: 1 - timer.progress(at: context.date), tint: Theme.Accent.timer, lineWidth: 2.6)
                    .frame(width: 15, height: 15)
            } trailing: {
                Text(TimerService.format(timer.remaining(at: context.date)))
                    .font(Theme.Typeface.wing)
                    .foregroundStyle(timer.isRunning ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(Motion.value, value: Int(timer.remaining(at: context.date)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer \(TimerService.format(timer.remaining()))")
    }
}

struct TimerFinishedActivity: View {
    @State private var ring = 0

    var body: some View {
        WingsLayout {
            Image(systemName: "timer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Accent.timer)
                .symbolEffect(.bounce, options: .repeat(3), value: ring)
        } trailing: {
            Text("Time's up")
                .font(Theme.Typeface.label)
                .foregroundStyle(Theme.Accent.timer)
        }
        .onAppear { ring += 1 }
    }
}

struct MeetingSoonActivity: View {
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        let event = calendar.events.first { $0.start > Date() }
        TimelineView(.periodic(from: .now, by: 15)) { context in
            WingsLayout {
                Circle()
                    .fill(event?.calendarColor ?? Theme.Accent.calendar)
                    .frame(width: 8, height: 8)
                    .modifier(PulseDot())
            } trailing: {
                if let event {
                    Text(Formatting.countdown(to: event.start, now: context.date))
                        .font(Theme.Typeface.label)
                        .foregroundStyle(Theme.Accent.calendar)
                }
            } bottom: {
                if let event {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(Theme.Typeface.title)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1)
                            Text(event.start.formatted(date: .omitted, time: .shortened) + (event.location.map { " · \($0)" } ?? ""))
                                .font(Theme.Typeface.body)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if event.meetingURL != nil {
                            BannerButton(title: "Join", symbol: "video.fill", tint: Theme.Accent.success) { calendar.join(event) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}
