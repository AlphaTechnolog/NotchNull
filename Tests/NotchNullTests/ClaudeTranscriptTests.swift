import XCTest
@testable import NotchNull

final class ClaudeTranscriptTests: XCTestCase {
    private func line(_ content: Any, extra: [String: Any] = [:]) -> [String: Any] {
        var json: [String: Any] = ["type": "user", "message": ["role": "user", "content": content]]
        extra.forEach { json[$0.key] = $0.value }
        return json
    }

    func testTypedPromptStartsATurn() {
        XCTAssertEqual(ClaudeTranscriptMonitor.userLine(line("Fix the login bug")), .turn(prompt: "Fix the login bug"))
    }

    func testToolResultKeepsTheTurnRunning() {
        let result = line([["type": "tool_result", "tool_use_id": "toolu_1", "content": "ok"]])
        XCTAssertEqual(ClaudeTranscriptMonitor.userLine(result), .turn(prompt: nil))
    }

    func testBackgroundTaskNotificationStartsATurnWithoutReplacingTheSummary() {
        let notification = line("<task-notification>\n<task-id>a1</task-id>\n</task-notification>")
        XCTAssertEqual(ClaudeTranscriptMonitor.userLine(notification), .turn(prompt: nil))
    }

    func testInterruptEndsTheTurn() {
        let escaped = line([["type": "text", "text": "[Request interrupted by user]"]])
        let rejectedTool = line([["type": "text", "text": "[Request interrupted by user for tool use]"]])
        XCTAssertEqual(ClaudeTranscriptMonitor.userLine(escaped), .interrupted)
        XCTAssertEqual(ClaudeTranscriptMonitor.userLine(rejectedTool), .interrupted)
    }

    func testLocalCommandsAndTheirOutputDoNotStartATurn() {
        let lines = [
            "<command-name>/model</command-name>\n<command-message>model</command-message>",
            "<local-command-stdout>Set model to opus</local-command-stdout>",
            "<bash-input>ls</bash-input>",
            "<bash-stdout>README.md</bash-stdout><bash-stderr></bash-stderr>",
        ]
        for text in lines {
            XCTAssertEqual(ClaudeTranscriptMonitor.userLine(line(text)), .bookkeeping, text)
        }
    }

    func testMetaAndCompactSummaryLinesDoNotStartATurn() {
        XCTAssertEqual(ClaudeTranscriptMonitor.userLine(line("## Context Usage", extra: ["isMeta": true])), .bookkeeping)
        XCTAssertEqual(
            ClaudeTranscriptMonitor.userLine(line("This session is being continued", extra: ["isCompactSummary": true])),
            .bookkeeping
        )
    }
}
