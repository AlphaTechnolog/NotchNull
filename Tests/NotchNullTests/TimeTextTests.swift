import SwiftUI
import XCTest
@testable import NotchNull

@MainActor
final class TimeTextTests: XCTestCase {
    private func size(_ value: String, widest: String) -> CGSize {
        let view = TimeText(value: value, widest: widest)
            .font(Theme.Typeface.wing)
            .foregroundStyle(Theme.Palette.textPrimary)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.cgImage else {
            XCTFail("TimeText did not render for \(value)")
            return .zero
        }
        return CGSize(width: image.width, height: image.height)
    }

    func testValuesShareTheWidestSlot() {
        let slot = size("59m 59s", widest: "59m 59s")
        XCTAssertEqual(size("9s", widest: "59m 59s"), slot)
        XCTAssertEqual(size("10s", widest: "59m 59s"), slot)
        XCTAssertEqual(size("59s", widest: "59m 59s"), slot)
        XCTAssertEqual(size("1m 0s", widest: "59m 59s"), slot)
    }

    func testHourFormIsShorterThanTheWidestMinuteForm() {
        let widest = size("59m 59s", widest: "59m 59s")
        let hour = size("1h 5m", widest: "1h 5m")
        XCTAssertLessThan(hour.width, widest.width)
    }
}
