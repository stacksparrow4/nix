import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const PREVIEW_LIMIT = 4000;

export default function(pi: ExtensionAPI) {
  let ask_mode = false;

  // Tool calls the user allowed to run, but whose output must be reviewed
  // before it is handed back to the agent.
  const review_output = new Set<string>();

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
        ["Yes", "Yes, review output before the agent sees it", "No"],
      );

      if (choice === "Yes") {
        return undefined;
      }

      if (choice === "Yes, review output before the agent sees it") {
        review_output.add(event.toolCallId);
        return undefined;
      }

      const reason = await ctx.ui.input(`Why should this be blocked?`);
      return { block: true, reason: `Blocked by user: ${reason}` };
    }

    return undefined;
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!review_output.delete(event.toolCallId)) {
      return undefined;
    }

    if (!ctx.hasUI) {
      return {
        content: [
          {
            type: "text" as const,
            text: "Output withheld: no UI available to review it.",
          },
        ],
        isError: true,
      };
    }

    const preview = event.content
      .map((part) =>
        part.type === "text" ? part.text : `[${part.type} content]`,
      )
      .join("\n");

    const truncated =
      preview.length > PREVIEW_LIMIT
        ? `${preview.slice(0, PREVIEW_LIMIT)}\n... [truncated ${preview.length - PREVIEW_LIMIT} chars]`
        : preview;

    const choice = await ctx.ui.select(
      `Give this output to the agent?\n\n${event.toolName}\n\n${truncated}`,
      ["Yes", "No"],
    );

    if (choice === "Yes") {
      return undefined;
    }

    const reason = await ctx.ui.input(`Why should this output be withheld?`);
    return {
      content: [
        {
          type: "text" as const,
          text: `Output withheld by user: ${reason}`,
        },
      ],
      isError: true,
    };
  });
}
