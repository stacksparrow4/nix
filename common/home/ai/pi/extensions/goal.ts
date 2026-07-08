import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

type Goal = {
	objective: string;
	status: "active" | "complete";
};

let goal: Goal | null = null;
let continuationQueued = false;

function continuationPrompt(objective: string): string {
	return `Continue working toward the active goal.

Objective: ${objective}

Choose the next concrete action toward the objective and avoid repeating work that is already done.

Before deciding the goal is achieved, verify against real evidence (files, command output, test results) that every requirement is met. Treat uncertainty as not done. When — and only when — the objective is fully achieved, call complete_goal. Do not call complete_goal for any other reason.`;
}

export default function goalExtension(pi: ExtensionAPI) {
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
			continuationQueued = false;
			return { content: [{ type: "text", text: "Goal marked complete." }] };
		},
	});

	pi.registerCommand("goal", {
		description: "Set a long-running goal the agent pursues until complete",
		handler: async (args, ctx) => {
			const objective = args.trim();
			if (!objective) {
				ctx.ui.notify("Usage: /goal <objective>", "info");
				return;
			}
			goal = { objective, status: "active" };
			continuationQueued = false;
			ctx.ui.notify(`Goal set: ${objective}`, "info");
			pi.sendMessage(
				{
					customType: "goal",
					content: continuationPrompt(objective),
					display: true,
				},
				{ triggerTurn: true, deliverAs: "followUp" },
			);
		},
	});

	pi.on("agent_end", (event, ctx) => {
		if (!goal || goal.status !== "active") return;

		// If the agent loop was aborted (e.g. the user pressed escape), cancel the
		// goal instead of automatically re-queuing the continuation prompt.
		const wasAborted = event.messages.some(
			(message) => message.role === "assistant" && message.stopReason === "aborted",
		);
		if (wasAborted) {
			goal = null;
			continuationQueued = false;
			ctx.ui.notify("Goal cancelled.", "info");
			return;
		}

		if (ctx.hasPendingMessages()) return;
		if (continuationQueued) return;
		continuationQueued = true;
		queueMicrotask(() => {
			continuationQueued = false;
			if (!goal || goal.status !== "active") return;
			pi.sendMessage(
				{
					customType: "goal",
					content: continuationPrompt(goal.objective),
					display: true,
				},
				{ triggerTurn: true, deliverAs: "followUp" },
			);
		});
	});
}
