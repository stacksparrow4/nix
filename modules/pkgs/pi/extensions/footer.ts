import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// --- Anthropic usage limits -------------------------------------------------
// Mirrors the standalone usage-limits extension, but renders the result inline
// in the custom footer instead of a separate status line. Data comes from the
// same endpoint Claude Code's /usage uses, authenticated with the OAuth access
// token Pi already stores in auth.json.
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage";
const AUTH_PATH = join(getAgentDir(), "auth.json");
/** Background refresh cadence. The 5h window moves slowly, so this is plenty. */
const USAGE_POLL_MS = 120_000;
/** Don't hammer the endpoint when turns finish back to back. */
const USAGE_MIN_REFRESH_MS = 20_000;
const USAGE_FETCH_TIMEOUT_MS = 8000;

// --- Shared usage cache -----------------------------------------------------
// The /api/oauth/usage endpoint is rate-limited *per account*, shared across
// every client that hits it (other Pi sessions, subagents, Claude Code's own
// /usage). When the limit is already spent, a fresh session's first request
// gets a 429 and would otherwise render nothing. So we persist the last good
// snapshot to a file in the host-mirrored sessions/ dir: every instance reads
// it on startup (showing a last-known value immediately) and only one instance
// needs to refresh within the freshness window, which keeps us off the limit.
const USAGE_CACHE_PATH = join(getAgentDir(), "sessions", "usage-cache.json");
/** If the cached snapshot is younger than this, skip the network entirely. */
const USAGE_CACHE_FRESH_MS = 90_000;
/** 429 backoff: start here, double each time, capped below. */
const USAGE_BACKOFF_BASE_MS = 60_000;
const USAGE_BACKOFF_MAX_MS = 15 * 60_000;

interface UsageCache {
  data: UsageResponse;
  fetchedAt: number;
}

function loadUsageCache(): UsageCache | undefined {
  try {
    const parsed = JSON.parse(readFileSync(USAGE_CACHE_PATH, "utf8"));
    if (parsed && typeof parsed.fetchedAt === "number" && parsed.data) {
      return parsed as UsageCache;
    }
  } catch {
    // No cache yet, or unreadable: treat as absent.
  }
  return undefined;
}

function saveUsageCache(data: UsageResponse): void {
  try {
    const payload: UsageCache = { data, fetchedAt: Date.now() };
    writeFileSync(USAGE_CACHE_PATH, JSON.stringify(payload));
  } catch {
    // Caching is best-effort; a write failure just means a future cold start
    // can't reuse this snapshot.
  }
}

/** Result of one usage fetch, so callers can distinguish 429 from other misses. */
type UsageFetch =
  | { kind: "ok"; data: UsageResponse }
  | { kind: "rate_limited"; retryAfterMs: number }
  | { kind: "skip" };

interface UsageWindow {
  utilization: number | null;
  resets_at: string | null;
}

interface UsageResponse {
  five_hour?: UsageWindow | null;
  seven_day?: UsageWindow | null;
  seven_day_opus?: UsageWindow | null;
  extra_usage?: { is_enabled?: boolean; utilization?: number | null } | null;
}

/** Pi keeps the OAuth credentials in auth.json and refreshes them on use. */
function readAccessToken(): string | undefined {
  try {
    const auth = JSON.parse(readFileSync(AUTH_PATH, "utf8"));
    const creds = auth?.anthropic;
    if (!creds || creds.type !== "oauth" || typeof creds.access !== "string") return undefined;
    // Expired tokens would just 401. Pi rewrites the file after its next
    // provider request, so skip and let the following poll pick it up.
    if (typeof creds.expires === "number" && creds.expires <= Date.now()) return undefined;
    return creds.access;
  } catch {
    return undefined;
  }
}

async function fetchUsage(): Promise<UsageFetch> {
  const token = readAccessToken();
  if (!token) return { kind: "skip" };
  const res = await fetch(USAGE_URL, {
    headers: {
      Authorization: `Bearer ${token}`,
      "anthropic-beta": "oauth-2025-04-20",
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(USAGE_FETCH_TIMEOUT_MS),
  });
  if (!res.ok) {
    if (res.status === 429) {
      // Header is in seconds and often 0/absent, so fall back to our own backoff.
      const retryAfterHeader = Number(res.headers.get("retry-after"));
      const retryAfterMs = Number.isFinite(retryAfterHeader) && retryAfterHeader > 0 ? retryAfterHeader * 1000 : 0;
      return { kind: "rate_limited", retryAfterMs };
    }
    return { kind: "skip" };
  }
  const data = (await res.json()) as UsageResponse;
  return { kind: "ok", data };
}

/** "2h13m", "18m", "3d4h" — compact time until the reset timestamp. */
function formatUsageDelta(resetsAt: string | null | undefined): string | undefined {
  if (!resetsAt) return undefined;
  const ms = new Date(resetsAt).getTime() - Date.now();
  if (!Number.isFinite(ms)) return undefined;
  if (ms <= 0) return "now";
  const mins = Math.floor(ms / 60_000);
  const days = Math.floor(mins / 1440);
  const hours = Math.floor((mins % 1440) / 60);
  const minutes = mins % 60;
  if (days > 0) return hours > 0 ? `${days}d${hours}h` : `${days}d`;
  if (hours > 0) return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
  return `${minutes}m`;
}

// "Usage 71% (reset 2h13m)" — 5h-window utilization and time until it resets.
function formatUsage(data: UsageResponse): string | undefined {
  const w = data.five_hour;
  if (!w || typeof w.utilization !== "number") return undefined;
  const reset = formatUsageDelta(w.resets_at);
  return `Usage ${Math.round(w.utilization)}%${reset ? ` (reset ${reset})` : ""}`;
}

// Mirror of the built-in footer's compact token formatting (not exported).
function formatTokens(count: number): string {
  if (count < 1000) return `${count}`;
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

// Cumulative Claude/LLM cost across all session entries. Mirrors the built-in
// footer's cost stat, summing usage.cost.total over assistant messages, tool
// results that carry usage, and branch summaries / compactions.
function totalCost(ctx: any): number {
  const entries = ctx.sessionManager?.getEntries?.() ?? [];
  let cost = 0;
  for (const e of entries) {
    if (e.type === "message" && e.message.role === "assistant") {
      cost += e.message.usage?.cost?.total ?? 0;
    } else if (e.type === "message" && e.message.role === "toolResult" && e.message.usage) {
      cost += e.message.usage.cost?.total ?? 0;
    } else if ((e.type === "branch_summary" || e.type === "compaction") && e.usage) {
      cost += e.usage.cost?.total ?? 0;
    }
  }
  return cost;
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

  // Anthropic usage-limit snapshot, refreshed in the background and rendered
  // inline in the footer below. Seeded from the shared on-disk cache so the
  // footer shows a last-known value even when our own fetch is rate-limited.
  let usageData: UsageResponse | undefined;
  let usageFetchedAt = 0;
  let usageInFlight: Promise<void> | undefined;
  let usageTimer: ReturnType<typeof setInterval> | undefined;
  let usageTicker: ReturnType<typeof setInterval> | undefined;
  // While rate-limited (429) we hold off on network calls until this time.
  let usageBackoffUntil = 0;
  let usageBackoffMs = USAGE_BACKOFF_BASE_MS;
  let usageRetryTimer: ReturnType<typeof setTimeout> | undefined;

  // Adopt the newest snapshot available on disk (possibly written by another
  // Pi instance). Returns true if that snapshot is fresh enough to skip a fetch.
  function adoptDiskCache(): boolean {
    const cache = loadUsageCache();
    if (cache && cache.fetchedAt > usageFetchedAt) {
      usageData = cache.data;
      usageFetchedAt = cache.fetchedAt;
      refresh();
    }
    return usageFetchedAt > 0 && Date.now() - usageFetchedAt < USAGE_CACHE_FRESH_MS;
  }

  function refreshUsage(force = false): Promise<void> {
    if (usageInFlight) return usageInFlight;
    const now = Date.now();
    // Respect an active 429 backoff regardless of force.
    if (now < usageBackoffUntil) {
      adoptDiskCache();
      return Promise.resolve();
    }
    if (!force && now - usageFetchedAt < USAGE_MIN_REFRESH_MS) return Promise.resolve();
    // Another instance may have refreshed recently; if so, don't spend a request.
    if (adoptDiskCache()) return Promise.resolve();
    usageInFlight = fetchUsage()
      .then((result) => {
        if (result.kind === "ok") {
          usageData = result.data;
          usageFetchedAt = Date.now();
          usageBackoffMs = USAGE_BACKOFF_BASE_MS; // reset backoff on success
          saveUsageCache(result.data);
        } else if (result.kind === "rate_limited") {
          const wait = Math.max(result.retryAfterMs, usageBackoffMs);
          usageBackoffUntil = Date.now() + wait;
          usageBackoffMs = Math.min(usageBackoffMs * 2, USAGE_BACKOFF_MAX_MS);
          // Fall back to whatever another instance may have on disk.
          adoptDiskCache();
          scheduleRetry(wait);
        } else {
          adoptDiskCache();
        }
        refresh();
      })
      .catch(() => {
        // Usage display is cosmetic: never surface network/auth noise.
        adoptDiskCache();
      })
      .finally(() => {
        usageInFlight = undefined;
      });
    return usageInFlight;
  }

  function scheduleRetry(afterMs: number) {
    if (usageRetryTimer) clearTimeout(usageRetryTimer);
    usageRetryTimer = setTimeout(() => {
      usageRetryTimer = undefined;
      void refreshUsage(true);
    }, afterMs + 250);
    usageRetryTimer.unref?.();
  }

  function startUsagePolling() {
    // Seed from disk immediately so a value shows up before any network call.
    adoptDiskCache();
    void refreshUsage(true);
    if (!usageTimer) {
      usageTimer = setInterval(() => void refreshUsage(true), USAGE_POLL_MS);
      usageTimer.unref?.();
    }
    // Keep the "resets in" countdown honest between polls.
    if (!usageTicker) {
      usageTicker = setInterval(refresh, 30_000);
      usageTicker.unref?.();
    }
  }

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

            // Context usage, e.g. "1045/1.0M (2.2%)"
            const usage = c.getContextUsage?.();
            const contextWindow = usage?.contextWindow ?? c.model?.contextWindow ?? 0;
            const percentValue = usage?.percent ?? 0;
            const percentStr = usage?.percent != null ? `${percentValue.toFixed(1)}%` : "?";
            const tokensStr = usage?.tokens != null ? `${usage.tokens}` : "?";
            const contextDisplay = `${tokensStr}/${formatTokens(contextWindow)} (${percentStr})`;
            const contextColor =
              percentValue > 90 ? "error" : percentValue > 70 ? "warning" : "dim";
            parts.push(theme.fg(contextColor, contextDisplay));

            // Tokens per second
            if (tpsText) parts.push(theme.fg("dim", tpsText));

            // Anthropic usage limits, e.g. "Usage 71% (reset 2h13m)"
            if (usageData) {
              const usageStr = formatUsage(usageData);
              if (usageStr) parts.push(theme.fg("dim", usageStr));
            }

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
    if (ctx.hasUI) startUsagePolling();
  });

  // A finished turn is exactly when the usage numbers have just changed.
  pi.on("agent_settled", (_event, ctx) => {
    lastCtx = ctx;
    void refreshUsage();
  });

  pi.on("session_shutdown", () => {
    if (usageTimer) clearInterval(usageTimer);
    if (usageTicker) clearInterval(usageTicker);
    if (usageRetryTimer) clearTimeout(usageRetryTimer);
    usageTimer = undefined;
    usageTicker = undefined;
    usageRetryTimer = undefined;
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
