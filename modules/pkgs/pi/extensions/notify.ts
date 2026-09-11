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

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;
    notify("Pi", "Ready for input");
  });
}
