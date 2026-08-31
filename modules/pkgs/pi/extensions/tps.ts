import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { FooterComponent } from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  // Timing for the in-flight assistant response.
  let requestSentAt: number | undefined;
  let firstToken: number | undefined;
  let tracking = false;

  // The current tok/s readout. Rendered inline by the custom footer; falls back
  // to a plain status line if the custom footer could not be installed.
  let tpsText: string | undefined;

  // Latest event context — the footer shim reads live model/context/session
  // state off it, since the setFooter factory isn't handed an AgentSession.
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

  // Reuse the built-in footer (which owns all the token/cost/context formatting)
  // via a shim session, then splice the tok/s in right after the context %.
  function installFooter(ctx: any) {
    if (footerInstalled || useStatusFallback) return;
    footerInstalled = true;
    try {
      ctx.ui.setFooter((tui: any, _theme: any, footerData: any) => {
        capturedTui = tui;

        // FooterComponent only touches these members of its "session"; back
        // them with the live extension context so the footer stays current.
        const shimSession: any = {
          get state() {
            return { model: lastCtx?.model, thinkingLevel: lastCtx?.thinkingLevel };
          },
          getContextUsage: () => lastCtx?.getContextUsage?.(),
          get sessionManager() {
            return lastCtx?.sessionManager;
          },
          modelRuntime: { isUsingSubscription: () => false },
        };

        const inner = new FooterComponent(shimSession, footerData);
        return {
          render(width: number): string[] {
            let lines: string[];
            try {
              lines = inner.render(width);
            } catch {
              return [];
            }
            if (tpsText && lines.length >= 2) {
              try {
                const line = lines[1];
                // The first run of 2+ spaces is the padding between the stats
                // (ending in the context %) and the right-aligned model name.
                const pad = line.match(/ {2,}/);
                if (pad && pad.index !== undefined) {
                  const inject = `  ${tpsText}`;
                  const injW = visibleWidth(inject);
                  const padW = pad[0].length;
                  // Plain text inherits the surrounding dim styling; removing an
                  // equal number of pad spaces keeps the line width unchanged.
                  if (padW > injW) {
                    lines[1] =
                      line.slice(0, pad.index) +
                      inject +
                      " ".repeat(padW - injW) +
                      line.slice(pad.index + padW);
                  }
                }
              } catch {
                // Leave the line untouched on any surprise.
              }
            }
            return lines;
          },
          dispose() {
            try {
              inner.dispose?.();
            } catch {
              // ignore
            }
          },
        };
      });
    } catch {
      // Custom footer unsupported in this build — degrade to a status line.
      useStatusFallback = true;
    }
  }

  // message_start only fires once the provider's first stream chunk lands, so
  // anchor time-to-first-token to the moment the request actually went out.
  pi.on("before_provider_request", () => {
    requestSentAt = Date.now();
  });

  pi.on("message_start", (event, ctx) => {
    lastCtx = ctx;
    if (event.message.role !== "assistant") return;
    if (ctx.hasUI && ctx.mode === "tui") installFooter(ctx);

    requestSentAt = undefined; // consumed; a stale value would inflate the next ttft
    firstToken = undefined;
    tracking = true;
    tpsText = undefined;
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

    tpsText = `${(output / (genMs / 1000)).toFixed(1)} tok/s`;
    refresh();
  });
}
