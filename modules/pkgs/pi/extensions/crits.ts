import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function presetGoal(pi: ExtensionAPI) {
  pi.registerCommand("crits", {
    description: "Find critical vulnerabilities in a codebase",
    handler: async (args, ctx) => {
      const command = `/goal Find a unique (known findings are listed in KNOWN_FINDINGS.md) critical vulnerability in the codebase. Verify identified vulnerabilities end to end by tracing code flow. Clone third party modules to refer to the source authoritatively instead of recalling from memory. Keep track of progress in PROGRESS.md.`;

      if (ctx.isIdle()) {
        pi.sendUserMessage(command, { expandPromptTemplates: true });
      } else {
        pi.sendUserMessage(command, { expandPromptTemplates: true, deliverAs: "followUp" });
      }
    },
  });
}
