import XCTest
@testable import NotchNull

final class JSONLTailReaderTests: XCTestCase {
    private func fixture(_ data: Data) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tail-\(UUID().uuidString).jsonl")
        try data.write(to: file)
        return file
    }

    private func append(_ data: Data, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    func testLargeLineAndMarkerAcrossChunkBoundary() throws {
        let text = String(repeating: "x", count: (1 << 20) - 7) + "MARKER" + String(repeating: "y", count: 3 << 20)
        let file = try fixture(Data(("skip\n" + text + "\nMARKER-end\n").utf8))
        let reader = JSONLTailReader()
        var lines: [Data] = []
        reader.readNewLines(of: file, markers: [Data("MARKER".utf8)]) { lines.append($0) }
        XCTAssertEqual(lines, [Data(text.utf8), Data("MARKER-end".utf8)])
        reader.readNewLines(of: file, markers: []) { _ in XCTFail("Unchanged file replayed") }
    }

    func testPartialLineAcrossPollsAndTruncation() throws {
        let file = try fixture(Data("first\npar".utf8))
        let reader = JSONLTailReader()
        var lines: [String] = []
        func read() { reader.readNewLines(of: file, markers: []) { lines.append(String(decoding: $0, as: UTF8.self)) } }
        read()
        try append(Data("tial\nunfinished".utf8), to: file)
        read()
        XCTAssertEqual(lines, ["first", "partial"])
        try Data("new\n".utf8).write(to: file)
        read()
        XCTAssertEqual(lines, ["first", "partial", "new"])
        reader.forget(file)
        XCTAssertFalse(reader.isTracking(file))
    }

    func testReadStopsAtInitialFileSize() throws {
        let file = try fixture(Data("first\n".utf8))
        let reader = JSONLTailReader()
        var lines: [Data] = []
        reader.readNewLines(of: file, markers: []) { data in
            lines.append(data)
            try! append(Data("second\n".utf8), to: file)
        }
        XCTAssertEqual(lines.count, 1)
        reader.readNewLines(of: file, markers: []) { lines.append($0) }
        XCTAssertEqual(lines, [Data("first".utf8), Data("second".utf8)])
    }
}
