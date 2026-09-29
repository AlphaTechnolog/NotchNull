import Foundation
import Network

/// Loopback-only HTTP endpoint that receives Claude Code hook events from `claude-hook.sh`.
/// Requests must carry the per-install token; anything else is dropped.
final class AgentEventServer {
    struct Request {
        var method = "POST"
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.notchnull.agent-server")
    private let token: String
    private let onRequest: (Request) -> Void
    private let maxBody = 1 << 20

    struct Response {
        var status = 200
        var body = Data()

        static func json(_ value: JSONValue, status: Int = 200) -> Response {
            Response(status: status, body: (try? JSONSerialization.data(withJSONObject: value.any, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])) ?? Data())
        }

        static func error(_ message: String, status: Int = 400) -> Response {
            json(.object(["ok": .bool(false), "error": .string(message)]), status: status)
        }
    }

    /// Answers `/v1/…` requests (the public local API) on the main thread; hook events keep
    /// their fire-and-forget 204.
    var apiHandler: ((Request) -> Response)?

    init(token: String, onRequest: @escaping (Request) -> Void) {
        self.token = token
        self.onRequest = onRequest
    }

    func start(port: UInt16) {
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    Log.agents.error("Agent event server failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            Log.agents.info("Agent event server listening on 127.0.0.1:\(port)")
        } catch {
            Log.agents.error("Agent event server could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = self.parse(buffer) {
                guard self.authorized(request) else {
                    self.respond(connection, status: "403 Forbidden")
                    return
                }
                if request.path.hasPrefix("/v1/"), let apiHandler = self.apiHandler {
                    self.respond(connection, Self.answerOnMain(request, with: apiHandler))
                    return
                }
                self.respond(connection, status: "204 No Content")
                self.onRequest(request)
                return
            }
            if isComplete || error != nil || buffer.count > self.maxBody {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buffer)
        }
    }

    /// Runs the API handler on the main thread, but never waits on it for long: a main thread held
    /// by a system prompt (Bluetooth, for one, blocks at launch until answered) must not wedge the
    /// server queue. A late request still runs once the main thread is free.
    private static func answerOnMain(_ request: Request, with handler: @escaping (Request) -> Response) -> Response {
        final class Box: @unchecked Sendable { var response: Response? }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            box.response = handler(request)
            done.signal()
        }
        guard done.wait(timeout: .now() + 4) == .success, let response = box.response else {
            return .error("NotchNull is busy: its main thread is waiting, often on a macOS permission prompt. Answer it, then try again.", status: 503)
        }
        return response
    }

    private func authorized(_ request: Request) -> Bool {
        request.headers["x-notchnull-token"] == token
    }

    private func respond(_ connection: NWConnection, _ response: Response) {
        let reason = [200: "OK", 400: "Bad Request", 404: "Not Found", 405: "Method Not Allowed", 503: "Service Unavailable"][response.status] ?? "OK"
        var head = "HTTP/1.1 \(response.status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n\r\n"
        if response.body.isEmpty { head = head.replacingOccurrences(of: "Content-Type: application/json\r\n", with: "") }
        var data = Data(head.utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func respond(_ connection: NWConnection, status: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    /// Returns a request once headers and the full Content-Length body have arrived.
    private func parse(_ data: Data) -> Request? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerEnd = data.range(of: separator),
              let head = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }
        var lines = head.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let body = data[headerEnd.upperBound...]
        guard body.count >= length else { return nil }
        return Request(method: String(requestLine[0]).uppercased(), path: String(requestLine[1]), headers: headers, body: Data(body.prefix(length)))
    }
}
