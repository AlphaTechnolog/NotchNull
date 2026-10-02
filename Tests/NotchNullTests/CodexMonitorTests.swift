import XCTest
@testable import NotchNull

@MainActor
final class CodexMonitorTests: XCTestCase {
    private func fixture() throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("notchnull-codex-\(UUID().uuidString)")
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let folder = root.appendingPathComponent(String(format: "%04d/%02d/%02d", parts.year!, parts.month!, parts.day!))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (root, folder)
    }

    private func event(_ type: String) -> String {
        let stamp = ISO8601DateFormatter().string(from: Date())
        return "{\"type\":\"event_msg\",\"timestamp\":\"\(stamp)\",\"payload\":{\"type\":\"\(type)\"}}\n"
    }

    private func rollout(in folder: URL, id: String, padding: Int = 0) throws -> URL {
        let file = folder.appendingPathComponent("rollout-\(id).jsonl")
        let meta = "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(id)\",\"cwd\":\"/project/\(id)\",\"originator\":\"codex_exec\"}}\n"
        let output = padding > 0 ? "{\"type\":\"response_item\",\"payload\":{\"type\":\"custom_tool_call_output\",\"output\":\"\(String(repeating: "x", count: padding))\"}}\n" : ""
        try Data((meta + event("task_started") + output).utf8).write(to: file)
        return file
    }

    private func append(_ text: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    private func refresh(_ monitor: CodexMonitor) {
        monitor.scan().forEach(monitor.apply)
    }

    func testEveryRunningSessionIsCountedBeyondTwelve() throws {
        let (root, folder) = try fixture()
        for index in 0..<20 { _ = try rollout(in: folder, id: "agent-\(index)") }
        let store = AgentSessionStore()
        let monitor = CodexMonitor(store: store, sessionsRoot: root)

        refresh(monitor)

        XCTAssertEqual(store.running.count, 20)
        XCTAssertEqual(Set(store.running.map(\.id)), Set((0..<20).map { "agent-\($0)" }))
        refresh(monitor)
        XCTAssertEqual(store.running.count, 20, "An unchanged poll must preserve every live session")
    }

    func testSessionDiscoveredAfterStartupRecoversStartBeforeLargeToolOutput() throws {
        let (root, folder) = try fixture()
        let store = AgentSessionStore()
        let monitor = CodexMonitor(store: store, sessionsRoot: root)
        refresh(monitor)
        let file = try rollout(in: folder, id: "long-turn", padding: 400_000)

        refresh(monitor)

        XCTAssertEqual(store.running.map(\.id), ["long-turn"])
        try append(event("task_complete"), to: file)
        refresh(monitor)
        XCTAssertEqual(store.sessions.first?.status, .done)
    }

    func testQuietSessionReturningUsesItsLatestStatus() throws {
        let (root, folder) = try fixture()
        let file = try rollout(in: folder, id: "resume")
        let store = AgentSessionStore()
        let monitor = CodexMonitor(store: store, sessionsRoot: root)
        refresh(monitor)
        try append(event("task_complete"), to: file)
        refresh(monitor)
        XCTAssertEqual(store.sessions.first?.status, .done)

        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-Constants.Agents.codexActiveWindow - 60)], ofItemAtPath: file.path)
        refresh(monitor)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        refresh(monitor)

        XCTAssertTrue(store.running.isEmpty, "Touching a completed rollout must never resurrect its old task_started")
    }
}
