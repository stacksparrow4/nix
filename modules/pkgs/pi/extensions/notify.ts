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

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;
    if (lastRunWasCancelled(ctx)) return;
    notify("Pi", "Ready for input");
  });
}
