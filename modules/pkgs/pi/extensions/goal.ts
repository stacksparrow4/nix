import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

type Goal = {
  objective: string;
  status: "active" | "complete";
};

const HANDOVER_PROMPT =
  "The conversation is about to be handed over to the next agent. Update the current documentation with handover notes. At most 5 turns, but most of the time it can be done in less.";
const HANDOVER_MAX_TURNS = 5;

// Lives on globalThis so it survives /reload, which re-evaluates this module.
const LIMIT_KEY = Symbol.for("sprrw.goal.limitPercent");
const limitStore = globalThis as unknown as { [LIMIT_KEY]?: number | null };

function getGoalLimit(): number | null {
  return limitStore[LIMIT_KEY] ?? null;
}

function setGoalLimit(percent: number | null) {
  limitStore[LIMIT_KEY] = percent;
}

function continuationPrompt(objective: string): string {
  return `Continue working toward the active goal.

Objective: ${objective}

Choose the next concrete action toward the objective and avoid repeating work that is already done. Maintain up-to-date and correct notes, remove incorrect or outdated notes.

Before deciding the goal is achieved, verify with evidence that every requirement is met. Call complete_goal if and only if the goal is fully verified to be achieved.`;
}

export default function goalExtension(pi: ExtensionAPI) {
  // Per-session state. Must live inside the factory: the extension module is
  // cached across session replacement (/new, fork, switchSession) and the factory
  // is re-invoked against a fresh session tool registry. Module-level state would
  // persist a stale `toolRegistered = true`, so the lazy registerTool below would
  // be skipped and complete_goal would be "not found" in the new session.
  let goal: Goal | null = null;
  let lastObjective: string | null = null;
  let resetDispatched = false;
  let toolRegistered = false;
  let handover: { turns: number; forcedAbort: boolean } | null = null;
  let breakLoop = false;
  let handoverNow = false;

  function publish() {
    const active = goal?.status === "active";
    pi.events.emit("goal:state", {
      active,
      objective: active ? goal!.objective : undefined,
      lastLap: active && breakLoop,
      handover: active && (handover !== null || handoverNow),
    });
  }

  // Only load complete_goal tool when /goal is used to avoid polluting context
  // This causes a cache invalidation (increasing token cost), however as i use goal early on its fine.
  function ensureToolRegistered() {
    if (toolRegistered) return;
    toolRegistered = true;
    pi.registerTool({
      name: "complete_goal",
      label: "Complete Goal",
      description:
        "Mark the current active goal complete. Call this only once the goal's objective is fully achieved and verified.",
      promptSnippet: "Mark the current goal complete after verifying the objective is fully achieved",
      promptGuidelines: [
        "Use complete_goal only when the current goal objective is fully achieved and verified against concrete evidence.",
        "Do not call complete_goal to pause, abandon, or stop a goal for any other reason.",
      ],
      parameters: Type.Object({}),
      async execute() {
        if (!goal) {
          return { content: [{ type: "text", text: "No goal is set." }], isError: true };
        }
        goal = { ...goal, status: "complete" };
        publish();
        return { content: [{ type: "text", text: "Goal marked complete." }], terminate: true };
      },
    });
  }

  pi.registerCommand("goal", {
    description: "Set a long-running goal the agent pursues until complete",
    handler: async (args, ctx) => {
      const objective = args.trim();
      if (!objective) {
        ctx.ui.notify("Usage: /goal <objective>", "info");
        return;
      }
      startGoal(objective, ctx);
    },
  });

  pi.registerCommand("goal-resume", {
    description: "Resume the last goal, re-running /goal with the same objective",
    handler: async (_args, ctx) => {
      if (!lastObjective) {
        ctx.ui.notify("No previous goal to resume.", "info");
        return;
      }
      startGoal(lastObjective, ctx);
    },
  });

  pi.registerCommand("goal-limit", {
    description:
      "Hand over to a fresh agent when context usage reaches a percentage (e.g. 10%, 'off', or 'now' for a one-off handover at the end of the current turn)",
    handler: async (args, ctx) => {
      const value = args.trim();
      if (!value) {
        const limit = getGoalLimit();
        ctx.ui.notify(limit === null ? "Goal limit: off" : `Goal limit: ${limit}%`, "info");
        return;
      }
      if (value === "now") {
        if (!goal || goal.status !== "active") {
          ctx.ui.notify("No active goal.", "info");
          return;
        }
        if (handover || resetDispatched) {
          ctx.ui.notify("Handover already in progress.", "info");
          return;
        }
        handoverNow = true;
        publish();
        ctx.ui.notify("Goal will hand over at the end of the current turn.", "info");
        return;
      }
      if (value === "off") {
        setGoalLimit(null);
        ctx.ui.notify("Goal limit disabled.", "info");
        return;
      }
      const match = value.match(/^(\d+(?:\.\d+)?)\s*%?$/);
      const percent = match ? Number(match[1]) : NaN;
      if (!(percent > 0 && percent <= 100)) {
        ctx.ui.notify("Usage: /goal-limit <percent>% | off | now", "info");
        return;
      }
      setGoalLimit(percent);
      ctx.ui.notify(`Goal limit set to ${percent}%`, "info");
    },
  });

  pi.registerCommand("goal-last-lap", {
    description: "Let the current goal run finish without resetting the context (on/off, toggles by default)",
    handler: async (args, ctx) => {
      if (!goal || goal.status !== "active") {
        ctx.ui.notify("No active goal.", "info");
        return;
      }
      if (resetDispatched) {
        ctx.ui.notify("Too late: the goal reset is already in progress.", "info");
        return;
      }
      const value = args.trim();
      if (value === "on") breakLoop = true;
      else if (value === "off") breakLoop = false;
      else if (!value) breakLoop = !breakLoop;
      else {
        ctx.ui.notify("Usage: /goal-last-lap [on|off]", "info");
        return;
      }
      publish();
      ctx.ui.notify(
        breakLoop ? "Last lap: the goal will end without resetting the context." : "Last lap off: the goal loop will continue.",
        "info",
      );
    },
  });

  pi.registerCommand("internal-goal-handover", {
    description: "Internal: restart the active goal in a fresh session",
    handler: async (_args, ctx) => {
      if (!goal || goal.status !== "active") return;
      const objective = goal.objective;
      goal = null;
      handover = null;
      publish();
      await ctx.waitForIdle();
      await ctx.newSession({
        withSession: async (newCtx) => {
          await newCtx.sendUserMessage(`/goal ${objective}`, { expandPromptTemplates: true });
        },
      });
    },
  });

  pi.registerCommand("crits", {
    description: "Find critical vulnerabilities in a codebase",
    handler: async (_args, ctx) => {
      const presetGoal = `Find a distinct critical vulnerability in the codebase.

- Store progress on leads in markdown files in ~/box/hunt/progress/
- Store the known finding within ~/box/hunt/known-findings/
- Create the above directories if they do not exist.
- A distinct vulnerability is one that is distinct from the other findings in ~/box/hunt/known-findings. Verify that the distinct vulnerability is different to all other findings in this directory.
- Verify identified vulnerabilities end to end by tracing code flow.
- The vulnerability chain may pass through code in open source third party libraries. Clone these libraries to refer to the source authoritatively instead of recalling from memory.
- Subagents can be used to investigate multiple paths at once. For more information use the bash command "subagent --help".`;
      startGoal(presetGoal, ctx);
    },
  });

  function startGoal(objective: string, ctx: ExtensionCommandContext) {
    ensureToolRegistered();
    goal = { objective, status: "active" };
    lastObjective = objective;
    publish();
    if (!ctx.isIdle()) {
      ctx.ui.notify(`Goal set: ${objective} (starts in a fresh session after the current run)`, "info");
      return;
    }
    resetDispatched = false;
    handover = null;
    breakLoop = false;
    handoverNow = false;
    publish();
    ctx.ui.notify(`Goal set: ${objective}`, "info");
    pi.sendMessage(
      {
        customType: "goal",
        content: continuationPrompt(objective),
        display: true,
      },
      { triggerTurn: true, deliverAs: "followUp" },
    );
  }

  pi.on("turn_end", (event, ctx) => {
    if (!goal || goal.status !== "active") return;

    if (handover) {
      if (handover.forcedAbort || breakLoop) return;
      handover.turns += 1;
      if (handover.turns >= HANDOVER_MAX_TURNS && event.toolResults.length > 0) {
        handover.forcedAbort = true;
        ctx.abort();
      }
      return;
    }

    if (breakLoop) return;
    const percent = ctx.getContextUsage()?.percent;
    const limit = getGoalLimit();
    if (!handoverNow && (limit === null || percent == null || percent < limit)) return;

    handoverNow = false;
    handover = { turns: 0, forcedAbort: false };
    publish();
    ctx.ui.notify(
      percent == null ? "Handing over goal." : `Context at ${percent.toFixed(1)}%, handing over goal.`,
      "info",
    );
    pi.sendMessage(
      {
        customType: "goal-handover",
        content: HANDOVER_PROMPT,
        display: true,
      },
      { deliverAs: "steer" },
    );
  });

  pi.on("agent_end", (event, ctx) => {
    if (!goal || goal.status !== "active") return;

    // Abort if user presses escape
    const wasAborted = event.messages.some(
      (message) => message.role === "assistant" && message.stopReason === "aborted",
    );
    if (wasAborted && !handover?.forcedAbort) {
      goal = null;
      handover = null;
      publish();
      ctx.ui.notify("Goal cancelled.", "info");
    }
  });

  pi.on("input", (event, ctx) => {
    if (!goal || goal.status !== "active") return;
    if (event.source === "extension" || !event.streamingBehavior) return;
    goal = null;
    handover = null;
    publish();
    ctx.ui.notify("Goal cancelled. Use /goal-resume to resume it.", "info");
  });

  pi.on("agent_settled", (event, ctx) => {
    if (!goal || goal.status !== "active" || resetDispatched) return;
    if (event.aborted && !handover?.forcedAbort) {
      goal = null;
      handover = null;
      publish();
      ctx.ui.notify("Goal cancelled.", "info");
      return;
    }
    if (breakLoop) {
      goal = null;
      handover = null;
      breakLoop = false;
      publish();
      ctx.ui.notify("Goal loop ended; context kept. Use /goal-resume to restart.", "info");
      return;
    }
    resetDispatched = true;
    pi.sendUserMessage("/internal-goal-handover", { expandPromptTemplates: true });
  });
}
