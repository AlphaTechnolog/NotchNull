import XCTest
@testable import NotchNull

final class DeviceTests: XCTestCase {
    func testQuarantineFromSharingdIsAirDrop() {
        XCTAssertTrue(AirDropWatcher.isAirDropQuarantine("0083;66f1a2b3;sharingd;5B1C2D3E-0000"))
    }

    func testBrowserQuarantineIsNotAirDrop() {
        XCTAssertFalse(AirDropWatcher.isAirDropQuarantine("0081;66f1a2b3;Brave Browser;5B1C2D3E-0000"))
        XCTAssertFalse(AirDropWatcher.isAirDropQuarantine("garbage"))
    }

    func testSerialBridgeChipsAreNamedAsBoards() {
        XCTAssertEqual(USBDeviceWatcher.boardName(product: "CP2102N USB to UART Bridge Controller", vendorID: 0x10C4), "ESP32 / CP210x board")
        XCTAssertEqual(USBDeviceWatcher.boardName(product: "USB Serial", vendorID: 0x1A86), "CH340 serial board")
        XCTAssertEqual(USBDeviceWatcher.boardName(product: "USB JTAG/serial debug unit", vendorID: 0x303A), "ESP32")
    }

    func testArduinoKeepsItsProductName() {
        XCTAssertEqual(USBDeviceWatcher.boardName(product: "Arduino Uno", vendorID: 0x2341), "Arduino Uno")
        XCTAssertEqual(USBDeviceWatcher.boardName(product: "Nano Every", vendorID: 0x2341), "Arduino Nano Every")
    }
}
