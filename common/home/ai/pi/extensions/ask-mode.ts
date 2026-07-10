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
    if (ask_mode) {
      if (!ctx.hasUI) {
        return {
          block: true,
          reason:
            "Ask-mode enabled in non-interactive mode, this should never happen",
        };
      }

      const details = JSON.stringify(event.input, null, 2);

      const choice = await ctx.ui.select(
        `Run the following tool?\n\n${event.toolName}\n\n${details}`,
        ["Yes", "No"],
      );

      if (choice !== "Yes") {
        const reason = await ctx.ui.input(`Why should this be blocked?`);
        return { block: true, reason: `Blocked by user: ${reason}` };
      }
    }

    return undefined;
  });
}
