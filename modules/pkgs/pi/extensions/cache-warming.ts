import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  let enabled = true;

  pi.on("session_start", () => {
    enabled = true;
  });

  pi.on("cache_warming_decision", (_event, _ctx) => {
    return { action: enabled ? "warm" : "stop" };
  });

  pi.registerCommand("warming", {
    description: "Toggle cache warming for this conversation",
    handler: async (_args: string, ctx: ExtensionCommandContext) => {
      enabled = !enabled;
      ctx.ui.notify(`Cache warming ${enabled ? "enabled" : "disabled"}`, "info");
    },
  });
}
