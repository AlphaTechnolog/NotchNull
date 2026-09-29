import SwiftUI

struct NeedsYouActivity: View {
    @EnvironmentObject private var sessions: AgentSessionStore

    var body: some View {
        let session = sessions.attention
        WingsLayout {
            ProviderMark(provider: session?.provider ?? .claude, animating: true, size: 16)
        } trailing: {
            HStack(spacing: 5) {
                Circle().fill(Theme.Accent.needsYou).frame(width: 6, height: 6)
                    .modifier(PulseDot())
                Text("Needs you")
                    .font(Theme.Typeface.label)
                    .foregroundStyle(Theme.Accent.needsYou)
            }
        } bottom: {
            if let session {
                Button {
                    TerminalJumper.jump(to: session)
                } label: {
                    BannerText(title: session.project, subtitle: message(session), subtitleLines: 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(hoverFill: .clear, padding: EdgeInsets()))
                .help(TerminalJumper.canJump(to: session) ? "Jump to the terminal" : "Open the Agents tab")
                .padding(.bottom, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Agent needs your approval")
    }

    private func message(_ session: AgentSession) -> String {
        if case .needsYou(let text) = session.status { return text }
        return "Waiting for you"
    }
}

/// Subtle breathing dot for live states.
struct PulseDot: ViewModifier {
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on && !Motion.reduceMotion ? 1.35 : 1)
            .opacity(on ? 0.6 : 1)
            .onAppear {
                guard !Motion.reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

struct AgentRunningActivity: View {
    @EnvironmentObject private var sessions: AgentSessionStore

    var body: some View {
        let running = sessions.running
        let oldest = running.compactMap(\.turnStartedAt).min()
        // Codex first so Claude's mark, the one that also tints the edge, sits whole on top.
        let providers = AgentProvider.allCases.reversed().filter { provider in running.contains { $0.provider == provider } }
        WingsLayout {
            HStack(spacing: 6) {
                ProviderStack(providers: providers.isEmpty ? [.claude] : providers, animating: true, size: 16)
                // The marks already say one session per provider; the count adds the extra ones.
                if running.count > max(providers.count, 1) {
                    Text("\(running.count)")
                        .font(Theme.Typeface.metric)
                        .foregroundStyle(providers.count == 1 ? providers[0].tint : Theme.Palette.textSecondary)
                        .contentTransition(.numericText(value: Double(running.count)))
                }
            }
            .animation(Motion.state, value: providers)
        } trailing: {
            if let oldest {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Formatting.elapsed(context.date.timeIntervalSince(oldest)))
                        .font(Theme.Typeface.wing)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(Motion.value, value: Int(context.date.timeIntervalSince(oldest)))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(running.count) agent session running")
    }
}

struct AgentDoneActivity: View {
    @EnvironmentObject private var sessions: AgentSessionStore
    @State private var popped = false

    var body: some View {
        let session = sessions.lastFinished
        WingsLayout {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Accent.success)
                .symbolEffect(.bounce, value: popped)
        } trailing: {
            if let duration = session?.lastTurnDuration {
                Text(Formatting.elapsed(duration))
                    .font(Theme.Typeface.wing)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        } bottom: {
            if let session {
                Button {
                    TerminalJumper.jump(to: session)
                } label: {
                    BannerText(
                        title: "\(session.project) is done",
                        subtitle: session.detail ?? "\(session.provider.title) finished its turn",
                        subtitleLines: 2
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(hoverFill: .clear, padding: EdgeInsets()))
                .padding(.bottom, 8)
            }
        }
        .onAppear { popped.toggle() }
    }
}

struct UsageWarningActivity: View {
    @EnvironmentObject private var agents: AgentHub

    var body: some View {
        let warning = agents.warning
        let tint = warning.map { $0.window.severity == .critical ? Theme.Accent.danger : Theme.Accent.warning } ?? Theme.Accent.warning
        WingsLayout {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: warning?.window.percent)
        } trailing: {
            if let warning {
                Text(Preferences.shared.usageShowsRemaining ? "\(Int((100 - warning.window.percent).rounded()))% left" : "\(Int(warning.window.percent))%")
                    .font(Theme.Typeface.wing)
                    .foregroundStyle(tint)
            }
        } bottom: {
            if let warning {
                BannerText(
                    title: "\(warning.provider) · \(warning.window.label) limit",
                    subtitle: Formatting.usageSummary(warning.window)
                )
                .padding(.bottom, 8)
            }
        }
    }
}
