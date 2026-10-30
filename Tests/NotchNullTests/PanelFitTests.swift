import XCTest
@testable import NotchNull

final class PanelFitTests: XCTestCase {
    func testChromeIsCardInsetsPlusPanelPadding() {
        XCTAssertEqual(PanelFit.cardPadding, 8)
        XCTAssertEqual(PanelFit.panelTopPadding, 4)
        XCTAssertEqual(PanelFit.panelBottomPadding, Theme.Radius.panelPadding)
        XCTAssertEqual(PanelFit.chromeHeight, 32)
    }

    func testOneTwoAndThreeBlockColumnsRoundUp() {
        // Natural heights of the measured column for a short one-, two- and three-block list.
        XCTAssertEqual(PanelFit.contentHeight(tallestColumn: 50), 82)
        XCTAssertEqual(PanelFit.contentHeight(tallestColumn: 117), 149)
        XCTAssertEqual(PanelFit.contentHeight(tallestColumn: 183.2), 216)
    }

    func testFractionalMeasurementRoundsUp() {
        XCTAssertEqual(PanelFit.contentHeight(tallestColumn: 52.01), 85)
        XCTAssertEqual(PanelFit.contentHeight(tallestColumn: 0.1), 33)
    }

    func testTallContentIsCappedByTheConfiguredHeight() {
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 260, configured: 148), 148)
    }

    func testShortContentShrinksBelowTheConfiguredHeight() {
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 82, configured: 148), 82)
    }

    func testCanvasClampWinsOverBothHeightAndConfiguredMaximum() {
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 260, configured: 148, canvasMaximum: 120), 120)
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 90, configured: 148, canvasMaximum: 70), 70)
    }

    func testUnmeasuredContentFallsBackToTheConfiguredHeight() {
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 0, configured: 148), 148)
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: .nan, configured: 148), 148)
        XCTAssertEqual(PanelFit.contentHeight(tallestColumn: .infinity), 0)
    }

    func testZeroAndDegenerateLimitsStayNonNegative() {
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 82, configured: 0), 0)
        XCTAssertEqual(PanelFit.fittedContentHeight(requested: 82, configured: 148, canvasMaximum: -10), 0)
    }
}
