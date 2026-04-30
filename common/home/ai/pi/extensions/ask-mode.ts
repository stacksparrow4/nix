import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function(pi: ExtensionAPI) {
  let ask_mode = false;

  pi.registerShortcut("ctrl+shift+a", {
    description: "Toggle ask mode",
    handler: async (ctx) => {
      ask_mode = !ask_mode;
      ctx.ui.notify(`Ask mode ${ask_mode ? "enabled" : "disabled"}`, "info");
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return undefined;

    const command = event.input.command as string;

    if (ask_mode) {
      if (!ctx.hasUI) {
        return { block: true, reason: "Ask-mode enabled in non-interactive mode, this should never happen" };
      }

      const choice = await ctx.ui.select(`Run the following command? ${command}`, ["Yes", "No"]);

      if (choice !== "Yes") {
        return { block: true, reason: "Blocked by user" };
      }
    }

    return undefined;
  });
}
