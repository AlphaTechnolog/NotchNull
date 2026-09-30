import XCTest
@testable import NotchNull

@MainActor
final class AgentAttentionTests: XCTestCase {
    func testQuestionShowsTheQuestionTextNotTheToolName() {
        let json: [String: Any] = [
            "tool_name": "AskUserQuestion",
            "tool_input": ["questions": [["question": "Should the API keep v1 routes?"]]],
        ]
        XCTAssertEqual(ClaudeHookHandler.describePermission(json), "Should the API keep v1 routes?")
    }

    func testSeveralQuestionsCountTheRest() {
        let json: [String: Any] = [
            "tool_name": "AskUserQuestion",
            "tool_input": ["questions": [["question": "Which database?"], ["question": "Which region?"], ["question": "Which plan?"]]],
        ]
        XCTAssertEqual(ClaudeHookHandler.describePermission(json), "Which database? (+2 more)")
    }

    func testQuestionWithoutTextFallsBackToPlainPhrase() {
        let json: [String: Any] = ["tool_name": "AskUserQuestion", "tool_input": [:] as [String: Any]]
        XCTAssertEqual(ClaudeHookHandler.describePermission(json), "Has a question for you")
    }

    func testPlanReviewReadsAsASentence() {
        XCTAssertEqual(ClaudeHookHandler.describePermission(["tool_name": "ExitPlanMode"]), "Has a plan ready for your review")
    }

    func testUnknownToolsAreSpelledAsWords() {
        XCTAssertEqual(ClaudeHookHandler.describePermission(["tool_name": "TodoWrite"]), "Wants to use todo write")
        XCTAssertEqual(ClaudeHookHandler.readableToolName("mcp__github__create_issue"), "create issue (github)")
        XCTAssertEqual(ClaudeHookHandler.readableToolName("mcp__linear__save_issue"), "save issue (linear)")
    }

    func testBannerGrowsPerWaitingSessionUpToTheVisibleRows() {
        let single = AttentionQueue.extraHeight(for: 1)
        let two = AttentionQueue.extraHeight(for: 2)
        let three = AttentionQueue.extraHeight(for: 3)
        let five = AttentionQueue.extraHeight(for: 5)
        XCTAssertEqual(AttentionQueue.extraHeight(for: 0), single)
        XCTAssertLessThan(two, three)
        XCTAssertEqual(three - two, 36)
        // Past the visible rows only the "+N more" line is added.
        XCTAssertEqual(five, three + 16)
        XCTAssertEqual(AttentionQueue.extraHeight(for: 9), five)
    }
}

final class PermissionConsentTests: XCTestCase {
    func testNewInstallStartsWithoutKeychainOrBluetoothAccess() {
        XCTAssertFalse(Preferences.consent(stored: nil, alreadySetUp: false))
    }

    func testInstallFromBeforeConsentKeepsItsAccess() {
        XCTAssertTrue(Preferences.consent(stored: nil, alreadySetUp: true))
    }

    func testSavedAnswerWinsOverSetupState() {
        XCTAssertFalse(Preferences.consent(stored: false, alreadySetUp: true))
        XCTAssertTrue(Preferences.consent(stored: true, alreadySetUp: false))
    }
}
