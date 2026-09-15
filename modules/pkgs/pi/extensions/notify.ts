import { connect } from "node:net";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SOCKET_PATH = process.env.PI_NOTIFY_SOCKET;

function notify(title: string, body: string): void {
  if (!SOCKET_PATH) return;
  try {
    const sock = connect(SOCKET_PATH);
    sock.on("error", () => {});
    sock.on("connect", () => {
      sock.end(`${title}\t${body}\n`);
    });
  } catch {
  }
}

function lastRunWasCancelled(ctx: {
  sessionManager: { getBranch(): Array<any> };
}): boolean {
  const branch = ctx.sessionManager.getBranch();
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if ("role" in msg && msg.role === "assistant") {
      return msg.stopReason === "aborted";
    }
  }
  return false;
}

const PREVIEW_LIMIT = 100;

function firstMessagePreview(ctx: {
  sessionManager: { getBranch(): Array<any> };
}): string | null {
  const branch = ctx.sessionManager.getBranch();
  for (const entry of branch) {
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (!("role" in msg) || msg.role !== "user") continue;
    const content = msg.content;
    const text = Array.isArray(content)
      ? content
          .map((part: any) => (part.type === "text" ? part.text : ""))
          .join("")
          .trim()
      : typeof content === "string"
        ? content.trim()
        : "";
    if (!text) continue;
    const singleLine = text.replace(/\s+/g, " ");
    return singleLine.length > PREVIEW_LIMIT
      ? `${singleLine.slice(0, PREVIEW_LIMIT)}\u2026`
      : singleLine;
  }
  return null;
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;
    if (lastRunWasCancelled(ctx)) return;
    const preview = firstMessagePreview(ctx);
    notify("Pi turn complete", preview || "");
  });
}
