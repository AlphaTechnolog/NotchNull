import SwiftUI
import XCTest
@testable import NotchNull

@MainActor
final class AgentsPanelFitTests: XCTestCase {
    private let geometry = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        notchSize: CGSize(width: 185, height: 32),
        hasHardwareNotch: true
    )
    private var wasSnapshot = false
    private var savedPanelWidth: Double = 500
    private var savedPanelHeight: Double = 148

    override func setUp() async throws {
        wasSnapshot = Motion.isSnapshot
        Motion.isSnapshot = true
        savedPanelWidth = Preferences.shared.panelWidth
        savedPanelHeight = Preferences.shared.panelHeight
        Preferences.shared.panelWidth = 500
        Preferences.shared.panelHeight = 148
    }

    override func tearDown() async throws {
        Motion.isSnapshot = wasSnapshot
        Preferences.shared.panelWidth = savedPanelWidth
        Preferences.shared.panelHeight = savedPanelHeight
    }

    private func requestedHeight(installed: Set<AgentProvider>, sessions: [AgentSession]) -> CGFloat? {
        let services = AppServices()
        services.agents.preview(warning: nil, hooksInstalled: true, opencodePluginInstalled: true, installed: installed)
        services.agents.plans.preview([])
        services.agents.sessions.preview(sessions)
        let usage = ProviderUsage(
            provider: .opencode,
            plan: "Pro",
            windows: [UsageWindow(id: "session", label: "5 hours", percent: 42, resetsAt: Date().addingTimeInterval(3600), duration: 5 * 3600)],
            state: .ready
        )
        if installed.contains(.claude) {
            services.agents.claudeUsage.preview(ProviderUsage(provider: .claude, plan: usage.plan, windows: usage.windows, state: .ready))
        }
        if installed.contains(.codex) {
            services.agents.codex.preview(
                usage: ProviderUsage(provider: .codex, plan: usage.plan, windows: usage.windows, state: .ready),
                tokens: TokenTally()
            )
        }
        if installed.contains(.opencode) {
            services.agents.opencode.preview(usage: usage, tokens: TokenTally())
        }

        let model = NotchViewModel(geometry: geometry, center: ActivityCenter())
        model.preview(phase: .open, tab: .agents)
        let view = AgentsTab()
            .frame(width: 476, height: 148)
            .environmentObject(model)
            .withServices(services)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        _ = renderer.cgImage
        return model.requestedPanelHeights[.agents]
    }

    func testOneInstalledAgentRequestsAShorterPanel() throws {
        let height = try XCTUnwrap(requestedHeight(
            installed: [.opencode],
            sessions: [AgentSession(id: "one", provider: .opencode, cwd: "/tmp/one", status: .running, updatedAt: Date())]
        ))
        XCTAssertLessThan(height, 148)
        XCTAssertEqual(height, PanelFit.contentHeight(tallestColumn: height - PanelFit.chromeHeight))
    }

    func testMoreProvidersAndSessionsRequestMoreHeight() throws {
        let one = try XCTUnwrap(requestedHeight(
            installed: [.opencode],
            sessions: [AgentSession(id: "one", provider: .opencode, cwd: "/tmp/one", status: .running, updatedAt: Date())]
        ))
        let manySessions = (0..<4).map {
            AgentSession(id: "s\($0)", provider: .opencode, cwd: "/tmp/s\($0)", status: .running, updatedAt: Date())
        }
        let many = try XCTUnwrap(requestedHeight(installed: Set(AgentProvider.allCases), sessions: manySessions))
        XCTAssertGreaterThan(many, one)
    }
}
