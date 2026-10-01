import Foundation

/// Installs (on explicit user action) the opencode plugin that forwards session
/// events to the notch. opencode autoloads `~/.config/opencode/plugins/*.js`,
/// so no `opencode.json` edit is needed and user config is never touched.
enum OpencodePluginInstaller {
    enum InstallError: LocalizedError {
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .writeFailed(let reason): "Could not write the opencode plugin: \(reason)"
            }
        }
    }

    static var pluginContents: String {
        """
        // \(Constants.Agents.hookMarker)-opencode: forwards opencode events to NotchNull.
        // Fire-and-forget; never throws so it can never block or alter opencode.
        export default {
          id: "notchnull",
          async setup(ctx) {
            const token = "\(ClaudeHookInstaller.token())";
            const port = \(Constants.Agents.eventServerPort);
            const controller = new AbortController();
            const post = (payload) => {
              try {
                const c = new AbortController();
                const t = setTimeout(() => { try { c.abort(); } catch {} }, 1000);
                fetch(`http://127.0.0.1:${port}/opencode`, {
                  method: "POST",
                  headers: { "Content-Type": "application/json", "X-NotchNull-Token": token },
                  body: JSON.stringify(payload),
                  signal: c.signal,
                }).then(() => clearTimeout(t)).catch(() => clearTimeout(t));
              } catch {}
            };
            const cwdOf = (sessionID) => {
              try { return ctx.location?.directory ?? ctx.session?.cwd ?? null; } catch { return null; }
              void sessionID;
              return null;
            };
            let permissionHook, promptHook, toolHook, toolAfterHook;
            try {
              permissionHook = ctx.permission.hook("evaluate", (event) => {
                try {
                  if (event && event.effect === "ask") {
                    const tool = event.tool || event.toolName || "a tool";
                    post({ sessionID: event.sessionID, event: "permission", cwd: cwdOf(event.sessionID), message: `Wants to use ${tool}` });
                  }
                } catch {}
              });
            } catch {}
            try {
              promptHook = ctx.session.hook("prompt", (event) => {
                try {
                  if (!event || !event.sessionID) return;
                  post({ sessionID: event.sessionID, event: "prompt", cwd: cwdOf(event.sessionID), message: event.message || event.prompt || null });
                } catch {}
              });
            } catch {}
            try {
              toolHook = ctx.tool.hook("execute.before", (event) => {
                try {
                  if (event && (event.tool === "question" || event.tool === "plan_exit") && event.sessionID) {
                    post({ sessionID: event.sessionID, event: "permission", cwd: cwdOf(event.sessionID), message: event.tool === "question" ? "Has a question" : "Plan ready for review" });
                  }
                } catch {}
              });
            } catch {}
            try {
              // Resume: answering a question / approving a plan lets the turn
              // continue, but no `prompt` fires — without this the notch stays
              // stuck on "needs you" until the turn completes. A null message
              // keeps the existing detail; the handler just flips to running.
              toolAfterHook = ctx.tool.hook("execute.after", (event) => {
                try {
                  if (event && (event.tool === "question" || event.tool === "plan_exit") && event.sessionID) {
                    post({ sessionID: event.sessionID, event: "prompt", cwd: cwdOf(event.sessionID), message: null });
                  }
                } catch {}
              });
            } catch {}
            (async () => {
              try {
                for await (const ev of ctx.event.subscribe({ signal: controller.signal })) {
                  try {
                    const e = typeof ev === "string" ? JSON.parse(ev) : ev;
                    if (!e || typeof e.type !== "string") continue;
                    const data = e.data || e.properties || {};
                    const sessionID = data.sessionID || data.sessionId || e.sessionID || null;
                    if (!sessionID) continue;
                    if (e.type === "session.execution.succeeded" || e.type === "session.idle") {
                      post({ sessionID, event: "complete", cwd: cwdOf(sessionID), message: data.message || data.text || null });
                    } else if (e.type === "session.execution.failed") {
                      post({ sessionID, event: "error", cwd: cwdOf(sessionID) });
                    } else if (e.type === "session.execution.interrupted") {
                      post({ sessionID, event: "error", cwd: cwdOf(sessionID) });
                    } else if (e.type === "permission.replied") {
                      // Approving/denying a permission also resumes the turn
                      // with no `prompt`; clear a stuck needs-you the same way.
                      post({ sessionID, event: "prompt", cwd: cwdOf(sessionID), message: null });
                    }
                  } catch {}
                }
              } catch {}
            })();
            return () => {
              try { controller.abort(); } catch {}
              try { permissionHook?.dispose?.(); } catch {}
              try { promptHook?.dispose?.(); } catch {}
              try { toolHook?.dispose?.(); } catch {}
              try { toolAfterHook?.dispose?.(); } catch {}
            };
          },
        };
        """
    }

    static var isInstalled: Bool {
        let url = Constants.Paths.opencodePlugin
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return contents.contains("\(Constants.Agents.hookMarker)-opencode")
    }

    static func install() throws {
        let url = Constants.Paths.opencodePlugin
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try pluginContents.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw InstallError.writeFailed(error.localizedDescription)
        }
    }

    /// Removes the plugin only when it is ours, so a user's own `notchnull.js` is never deleted.
    static func uninstall() throws {
        let url = Constants.Paths.opencodePlugin
        do {
            if isInstalled {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            throw InstallError.writeFailed(error.localizedDescription)
        }
    }
}
