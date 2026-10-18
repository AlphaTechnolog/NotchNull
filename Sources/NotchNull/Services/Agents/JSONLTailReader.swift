import Foundation

/// Reads only the bytes appended to JSON-lines files since the last call, handing complete lines
/// that contain a marker to the caller. Not thread-safe: use from one serial queue.
final class JSONLTailReader {
    private var offsets: [URL: UInt64] = [:]
    private var carry: [URL: Data] = [:]
    private let chunkSize = 1 << 20

    /// Starts tracking `url` at `offset` (e.g. file end, to skip history).
    func seed(_ url: URL, at offset: UInt64) {
        offsets[url] = offset
        carry[url] = nil
    }

    func isTracking(_ url: URL) -> Bool { offsets[url] != nil }

    func forget(_ url: URL) {
        offsets[url] = nil
        carry[url] = nil
    }

    /// Calls `line` for each new complete line containing any of `markers` (byte search, no JSON parse).
    func readNewLines(of url: URL, markers: [Data], line: (Data) -> Void) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        var offset = offsets[url] ?? 0
        if size < offset {
            offset = 0
            carry[url] = nil
        }
        guard size > offset else { return }
        try? handle.seek(toOffset: offset)
        var pending = carry[url] ?? Data()
        while offset < size {
            let chunk = handle.readData(ofLength: min(chunkSize, Int(size - offset)))
            if chunk.isEmpty { break }
            offset += UInt64(chunk.count)
            // Search only the new bytes. Re-scanning/copying the accumulated partial line
            // on every chunk makes large tool outputs quadratic in CPU and allocations.
            var start = chunk.startIndex
            while let newline = chunk[start...].firstIndex(of: 0x0A) {
                let slice = chunk[start..<newline]
                if pending.isEmpty {
                    if markers.isEmpty || markers.contains(where: { slice.range(of: $0) != nil }) {
                        autoreleasepool { line(Data(slice)) }
                    }
                } else {
                    pending.append(slice)
                    if markers.isEmpty || markers.contains(where: { pending.range(of: $0) != nil }) {
                        autoreleasepool { line(pending) }
                    }
                    pending = Data()
                }
                start = chunk.index(after: newline)
            }
            pending.append(chunk[start...])
        }
        offsets[url] = offset
        carry[url] = pending.isEmpty ? nil : pending
    }
}

extension String {
    var utf8Data: Data { Data(utf8) }
}
