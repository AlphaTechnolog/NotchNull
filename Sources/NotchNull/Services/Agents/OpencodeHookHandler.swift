import Foundation

/// Translates opencode plugin payloads (`POST /opencode`) into session state.
/// Payload shape (from `~/.config/opencode/plugins/notchnull.js`):
/// `{sessionID, event: prompt|permission|complete|error, cwd, title, message}`.
/// Accepts `session_id` / `hook_event_name` aliases defensively; unknown shapes
/// are ignored so the plugin can never corrupt session state.
@MainActor
struct OpencodeHookHandler {
    let store: AgentSessionStore

    func handle(_ request: AgentEventServer.Request) {
        guard request.path == "/opencode" else { return }
        guard Preferences.shared.opencodeEnabled else { return }
        guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else { return }
        let sessionID = (json["sessionID"] as? String) ?? (json["session_id"] as? String)
        let event = (json["event"] as? String) ?? (json["hook_event_name"] as? String)
        guard let sessionID, !sessionID.isEmpty, let event else { return }
        let cwd = json["cwd"] as? String
        let title = json["title"] as? String
        let message = json["message"] as? String

        store.upsert(id: sessionID, provider: .opencode) { session in
            if let cwd, !cwd.isEmpty { session.cwd = cwd }
            switch event {
            case "prompt", "user_message", "session_started":
                session.status = .running
                if session.turnStartedAt == nil { session.turnStartedAt = Date() }
                if let text = message ?? title, let summary = ClaudeHookHandler.summary(text, limit: 80) {
                    session.detail = summary
                } else if let title, !title.isEmpty {
                    session.detail = title
                }
            case "permission", "question":
                let text = message ?? title ?? "opencode needs your attention"
                session.status = .needsYou(ClaudeHookHandler.summary(text, limit: 120) ?? text)
            case "complete":
                session.status = .done
                if let text = message, let summary = ClaudeHookHandler.summary(text, limit: 160) {
                    session.detail = summary
                } else if let title, !title.isEmpty {
                    session.detail = title
                }
            case "error", "cancelled", "interrupted":
                if session.status == .running { session.status = .idle }
            default:
                break
            }
        }
    }
}
