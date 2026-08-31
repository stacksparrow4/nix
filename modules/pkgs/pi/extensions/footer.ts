import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// Mirror of the built-in footer's compact token formatting (not exported).
function formatTokens(count: number): string {
  if (count < 1000) return `${count}`;
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

// Cache-hit rate of the most recent assistant turn on the active branch.
function latestCacheHitRate(ctx: any): number | undefined {
  const entries = ctx.sessionManager?.getBranch?.() ?? [];
  for (let i = entries.length - 1; i >= 0; i--) {
    const e = entries[i];
    if (e.type === "message" && e.message.role === "assistant" && e.message.usage) {
      const u = e.message.usage;
      const prompt = (u.input ?? 0) + (u.cacheRead ?? 0) + (u.cacheWrite ?? 0);
      return prompt > 0 ? (u.cacheRead / prompt) * 100 : undefined;
    }
  }
  return undefined;
}

export default function (pi: ExtensionAPI) {
  // Timing for the in-flight assistant response.
  let firstToken: number | undefined;
  let tracking = false;

  // The current tok/s readout, rendered inline by the custom footer.
  let tpsText: string | undefined;

  // Running totals for the average tok/s across the whole response (all turns
  // in the agent loop), reset when a new agent run starts.
  let totalOutput = 0;
  let totalGenMs = 0;

  // Latest event context — the footer renders live model/context/session state
  // off it, since the setFooter factory isn't handed an AgentSession.
  let lastCtx: any;
  let capturedTui: { requestRender(force?: boolean): void } | undefined;
  let footerInstalled = false;
  let useStatusFallback = false;

  function refresh() {
    if (useStatusFallback) {
      lastCtx?.ui?.setStatus?.("tps", tpsText);
    } else {
      capturedTui?.requestRender();
    }
  }

  // A fully custom footer: cache hit, context usage, tok/s on the left; model /
  // provider / thinking level right-aligned. All data is read from the live
  // extension context (the intended setFooter API), so there's no shim session
  // and no splicing into the built-in footer's output.
  function installFooter(ctx: any) {
    if (footerInstalled || useStatusFallback) return;
    footerInstalled = true;
    try {
      ctx.ui.setFooter((tui: any, theme: any, footerData: any) => {
        capturedTui = tui;
        return {
          render(width: number): string[] {
            const c = lastCtx ?? ctx;
            const parts: string[] = [];

            // Cache hit
            const ch = latestCacheHitRate(c);
            if (ch !== undefined) parts.push(theme.fg("dim", `CH${ch.toFixed(1)}%`));

            // Context usage, e.g. "2.2%/1.0M"
            const usage = c.getContextUsage?.();
            const contextWindow = usage?.contextWindow ?? c.model?.contextWindow ?? 0;
            const percentValue = usage?.percent ?? 0;
            const percentStr = usage?.percent != null ? `${percentValue.toFixed(1)}%` : "?";
            const contextDisplay = `${percentStr}/${formatTokens(contextWindow)}`;
            const contextColor =
              percentValue > 90 ? "error" : percentValue > 70 ? "warning" : "dim";
            parts.push(theme.fg(contextColor, contextDisplay));

            // Tokens per second
            if (tpsText) parts.push(theme.fg("dim", tpsText));

            const left = parts.join(" ");

            // Right side: model name, provider prefix (when ambiguous), thinking level.
            const model = c.model;
            const modelName = model?.id || "no-model";
            let right = modelName;
            if (model?.reasoning) {
              const level = c.thinkingLevel || "off";
              right = level === "off" ? `${modelName} • thinking off` : `${modelName} • ${level}`;
            }
            // Prefix provider only when more than one is configured (and it fits).
            const providerCount = footerData?.getAvailableProviderCount?.() ?? 1;
            if (providerCount > 1 && model?.provider) {
              const withProvider = `(${model.provider}) ${right}`;
              if (visibleWidth(left) + 2 + visibleWidth(withProvider) <= width) {
                right = withProvider;
              }
            }
            right = theme.fg("dim", right);

            const leftW = visibleWidth(left);
            const rightW = visibleWidth(right);
            const minPad = 2;

            if (leftW + minPad + rightW <= width) {
              const pad = " ".repeat(width - leftW - rightW);
              return [left + pad + right];
            }

            // Not enough room: keep the left stats, truncate/drop the model.
            const availForRight = width - leftW - minPad;
            if (availForRight > 0) {
              const truncated = truncateToWidth(right, availForRight, "");
              const pad = " ".repeat(Math.max(0, width - leftW - visibleWidth(truncated)));
              return [left + pad + truncated];
            }
            return [truncateToWidth(left, width, theme.fg("dim", "..."))];
          },
          dispose() {},
        };
      });
    } catch {
      // Custom footer unsupported in this build — degrade to a status line.
      useStatusFallback = true;
    }
  }

  // Install the custom footer up front so it's shown before any message is sent,
  // not just once the first assistant response starts.
  pi.on("session_start", (_event, ctx) => {
    lastCtx = ctx;
    if (ctx.hasUI && ctx.mode === "tui") installFooter(ctx);
  });

  // A new agent run starts a fresh response; reset the average accumulators so
  // the "avg" reflects only the current response's turns.
  pi.on("agent_start", (_event, ctx) => {
    lastCtx = ctx;
    totalOutput = 0;
    totalGenMs = 0;
  });

  // message_start only fires once the provider's first stream chunk lands, so we
  // reset timing state here and anchor tok/s to the first token below.
  pi.on("message_start", (event, ctx) => {
    lastCtx = ctx;
    if (event.message.role !== "assistant") return;
    if (ctx.hasUI && ctx.mode === "tui") installFooter(ctx);

    firstToken = undefined;
    tracking = true;
    // Keep the previous tok/s visible while the next response generates; it's
    // replaced once this turn finishes and a fresh rate is computed.
    refresh();
  });

  // Record when generation actually starts so the rate excludes time-to-first-token.
  pi.on("message_update", (event) => {
    if (!tracking || firstToken !== undefined) return;
    const delta = (event.assistantMessageEvent as any)?.delta;
    if (typeof delta !== "string" || delta.length === 0) return;
    firstToken = Date.now();
  });

  pi.on("message_end", (event, ctx) => {
    lastCtx = ctx;
    if (!tracking || event.message.role !== "assistant" || !ctx.hasUI) return;
    tracking = false;

    const usage = (event.message as any).usage ?? {};
    const output: number = usage.output ?? 0; // already includes reasoning tokens
    const genMs = Math.max(0, Date.now() - (firstToken ?? Date.now()));
    if (output <= 0 || genMs <= 0) return;

    totalOutput += output;
    totalGenMs += genMs;

    const tps = output / (genMs / 1000);
    const avg = totalOutput / (totalGenMs / 1000);
    tpsText = `${tps.toFixed(1)}tps (${avg.toFixed(1)} avg)`;
    refresh();
  });
}
