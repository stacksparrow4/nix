import type { AssistantMessage, Message, ToolResultMessage, UserMessage } from "@earendil-works/pi-ai";
import {
  convertToLlm,
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { type Component, Markdown, type TUI, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const WIDGET_KEY = "btw";
const COLLAPSED_LINES = 10;
const MAX_TOOL_ROUNDS = 2;
const EXPAND_KEY = "ctrl+shift+b";

const TOOLS_DISABLED =
  "Tool calls are disabled for /btw. Answer using only the existing conversation context.";

function sideQuestionPrompt(question: string): string {
  return [
    "[/btw side question]",
    "The user is asking a quick side question about this conversation. It is not a new task and not a continuation of your current work.",
    "Tool calls are disabled: do not call any tools. Answer directly and concisely from the existing conversation context. If the context is insufficient, say so briefly.",
    "",
    `Question: ${question}`,
  ].join("\n");
}

type Phase = "pending" | "streaming" | "done" | "error";

interface BtwState {
  question: string;
  answer: string;
  phase: Phase;
  error?: string;
  controller: AbortController;
}

function textOf(message: AssistantMessage): string {
  return message.content
    .filter((part): part is { type: "text"; text: string } => part.type === "text")
    .map((part) => part.text)
    .join("");
}

function completeContext(messages: Message[]): Message[] {
  let end = messages.length;
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role !== "assistant") continue;
    const calls = message.content.filter((part) => part.type === "toolCall");
    if (calls.length === 0) break;
    const results = new Set(
      messages
        .slice(i + 1, end)
        .filter((m): m is ToolResultMessage => m.role === "toolResult")
        .map((m) => m.toolCallId),
    );
    if (calls.every((call) => results.has(call.id))) break;
    end = i;
  }
  return messages.slice(0, end);
}

export default function (pi: ExtensionAPI) {
  let state: BtwState | undefined;
  let expanded = false;
  let tui: TUI | undefined;

  const requestRender = () => tui?.requestRender();

  const clear = (ctx: ExtensionContext) => {
    state?.controller.abort();
    state = undefined;
    expanded = false;
    tui = undefined;
    if (ctx.hasUI) ctx.ui.setWidget(WIDGET_KEY, undefined);
  };

  const createWidget = (widgetTui: TUI, theme: Theme): Component => {
    tui = widgetTui;
    const markdown = new Markdown("", 2, 0, getMarkdownTheme());

    const rule = (width: number) => theme.fg("borderMuted", "┄".repeat(width));

    const header = (width: number, question: string) => {
      const label = truncateToWidth(
        theme.fg("accent", "/btw ") + theme.fg("muted", question.replace(/\s+/g, " ")),
        Math.max(0, width - 4),
      );
      const fill = Math.max(0, width - 4 - visibleWidth(label));
      return theme.fg("borderMuted", "┄┄ ") + label + " " + theme.fg("borderMuted", "┄".repeat(fill));
    };

    const footer = (width: number, left: string) => {
      const right = theme.fg("dim", "/btw to dismiss");
      const gap = Math.max(1, width - visibleWidth(left) - visibleWidth(right) - 2);
      return truncateToWidth("  " + left + " ".repeat(gap) + right, width);
    };

    return {
      render(width: number): string[] {
        if (!state) return [];
        const lines = [header(width, state.question)];

        if (state.phase === "error") {
          lines.push(truncateToWidth("  " + theme.fg("error", state.error ?? "/btw failed"), width));
          lines.push(footer(width, ""));
          lines.push(rule(width));
          return lines;
        }

        if (!state.answer) {
          lines.push("  " + theme.fg("dim", state.phase === "done" ? "(empty answer)" : "thinking…"));
          lines.push(footer(width, ""));
          lines.push(rule(width));
          return lines;
        }

        markdown.setText(state.answer);
        const body = markdown.render(width);
        const hidden = expanded ? 0 : Math.max(0, body.length - COLLAPSED_LINES);
        lines.push(...(hidden > 0 ? body.slice(0, COLLAPSED_LINES) : body));

        const status: string[] = [];
        if (state.phase !== "done") status.push("streaming…");
        if (hidden > 0) status.push(`… (+${hidden} lines) · ${EXPAND_KEY} to expand`);
        else if (expanded && body.length > COLLAPSED_LINES) status.push(`${EXPAND_KEY} to collapse`);
        lines.push(footer(width, theme.fg("dim", status.join(" · "))));
        lines.push(rule(width));
        return lines;
      },
      invalidate() {
        markdown.invalidate();
      },
    };
  };

  const run = async (ctx: ExtensionContext, current: BtwState) => {
    const model = ctx.model;
    if (!model) throw new Error("/btw requires an active model");

    const level = pi.getThinkingLevel();
    const messages: Message[] = [
      ...completeContext(convertToLlm(ctx.sessionManager.buildSessionProjection().messages)),
      {
        role: "user",
        content: [{ type: "text", text: sideQuestionPrompt(current.question) }],
        timestamp: Date.now(),
      } satisfies UserMessage,
    ];

    let previous = "";
    for (let round = 0; ; round++) {
      const stream = ctx.modelRegistry.streamSimple(
        model,
        { messages },
        {
          sessionId: ctx.sessionManager.getSessionId(),
          reasoning: level === "off" ? undefined : level,
          signal: current.controller.signal,
          transformHeaders: (headers) => {
            const request = { model, headers };
            pi.events.emit("provider:transform-headers", request);
            return request.headers;
          },
          onPayload: (payload, requestModel) => {
            const request: { model: typeof requestModel; payload: unknown; error?: string } = {
              model: requestModel,
              payload,
            };
            pi.events.emit("provider:transform-payload", request);
            if (request.error) throw new Error(request.error);
            return request.payload;
          },
        },
      );

      for await (const event of stream) {
        if (state !== current) return;
        if ("partial" in event) {
          current.phase = "streaming";
          current.answer = previous + textOf(event.partial);
          requestRender();
        }
      }

      const response = await stream.result();
      if (state !== current) return;
      if (response.stopReason === "aborted") return;
      if (response.stopReason === "error") {
        throw new Error(response.errorMessage ?? "/btw request failed");
      }

      previous += textOf(response);
      current.answer = previous;

      const calls = response.content.filter((part) => part.type === "toolCall");
      if (calls.length === 0) return;
      if (round >= MAX_TOOL_ROUNDS) {
        if (!previous.trim()) throw new Error("/btw: model kept trying to call tools");
        return;
      }

      messages.push(
        response,
        ...calls.map(
          (call): ToolResultMessage => ({
            role: "toolResult",
            toolCallId: call.id,
            toolName: call.name,
            content: [{ type: "text", text: TOOLS_DISABLED }],
            isError: true,
            timestamp: Date.now(),
          }),
        ),
      );
      if (previous && !previous.endsWith("\n")) previous += "\n\n";
    }
  };

  pi.registerCommand("btw", {
    description: "Ask a side question without adding it to the conversation (no args: dismiss)",
    handler: async (args, ctx) => {
      const question = args.trim();
      if (!question) {
        clear(ctx);
        return;
      }
      if (!ctx.hasUI) {
        ctx.ui.notify("/btw requires interactive mode", "error");
        return;
      }

      state?.controller.abort();
      const current: BtwState = {
        question,
        answer: "",
        phase: "pending",
        controller: new AbortController(),
      };
      state = current;
      expanded = false;
      ctx.ui.setWidget(WIDGET_KEY, createWidget, { placement: "aboveEditor" });

      void run(ctx, current)
        .then(() => {
          if (state !== current) return;
          current.phase = "done";
          requestRender();
        })
        .catch((error: unknown) => {
          if (state !== current || current.controller.signal.aborted) return;
          current.phase = "error";
          current.error = error instanceof Error ? error.message : String(error);
          requestRender();
        });
    },
  });

  pi.registerShortcut(EXPAND_KEY, {
    description: "Toggle expanded /btw answer",
    handler: async () => {
      if (!state) return;
      expanded = !expanded;
      requestRender();
    },
  });

  pi.on("input", (event, ctx) => {
    if (state && event.source === "interactive") clear(ctx);
  });

  pi.on("session_start", (_event, ctx) => clear(ctx));
  pi.on("session_shutdown", (_event, ctx) => clear(ctx));
}
