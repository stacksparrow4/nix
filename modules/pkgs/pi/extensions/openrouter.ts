import {
  BorderedLoader,
  DynamicBorder,
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  type Component,
  type Focusable,
  Input,
  type TUI,
  fuzzyFilter,
  getKeybindings,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// OpenRouter requests are pinned to a single endpoint. There is no automatic
// routing: a model with no pin raises an error telling the user to run
// /or-model, and the picked endpoint is written to a shared save file so pins
// survive restarts. Only the openai-completions transport honours the
// `provider` routing field, so only those models are pinned/blocked. Other
// transports still show the endpoint/cost table in view-only mode.

const PROVIDER = "openrouter";
const ROUTING_API = "openai-completions";
const OPENROUTER_API = "https://openrouter.ai/api/v1";

// The ZDR list is exactly the model pages' `!(training || retainsPrompts)` set;
// it is fetched separately because the per-model endpoint response does not
// include data-retention information.
const ZDR_ENDPOINTS = `${OPENROUTER_API}/endpoints/zdr`;

const AUTH_PATH = join(getAgentDir(), "auth.json");
const PINS_FILE = "openrouter-pins.json";
const MAX_VISIBLE_ROWS = 14;

// OpenRouter prices are USD; the picker shows estimated costs in AUD.
// Static approximation (1 USD ≈ 1.44 AUD, mid-Oct 2026) — it will drift, so
// treat the converted figures as a rough guide, not a live quote.
const USD_TO_AUD = 1.44;

// Derived from a 31-call agentic session: 32,350 fresh input and 25,030 output
// tokens, scaled to a 100k-token final context with perfect prompt caching.
const CONTEXT_TOKENS = 100_000;
const EMPIRICAL_INPUT_TOKENS = 32_350;
const EMPIRICAL_OUTPUT_TOKENS = 25_030;
const EMPIRICAL_CALLS = 31;
const GROWTH_PER_CALL = (EMPIRICAL_INPUT_TOKENS + EMPIRICAL_OUTPUT_TOKENS) / EMPIRICAL_CALLS;
const INPUT_SHARE = EMPIRICAL_INPUT_TOKENS / (EMPIRICAL_INPUT_TOKENS + EMPIRICAL_OUTPUT_TOKENS);

type Endpoint = Record<string, any>;

interface Row {
  tag: string;
  provider: string;
  quant: string;
  zdr: boolean | null;
  context: number | null;
  cost: number;
  throughput: Record<string, number | null>;
}

const THROUGHPUT_PERCENTILE = /^p\d+$/;

interface Pin {
  tag: string;
  provider: string;
  quant: string;
  pinnedAt: number;
}

type PinStore = Record<string, Pin>;

// --- Pin store ------------------------------------------------------------

function pinsPath(): string {
  return join(getAgentDir(), "sessions", PINS_FILE);
}

function loadPins(): PinStore {
  try {
    const parsed = JSON.parse(readFileSync(pinsPath(), "utf8"));
    if (parsed && typeof parsed === "object") return parsed as PinStore;
  } catch {}
  return {};
}

function savePins(store: PinStore): void {
  try {
    writeFileSync(pinsPath(), `${JSON.stringify(store, null, 2)}\n`);
  } catch {
    // Best-effort; a write failure only costs the pin on the next restart.
  }
}

let pins: PinStore = loadPins();

function isRoutingModel(
  model: ExtensionContext["model"],
): model is NonNullable<ExtensionContext["model"]> {
  return !!model && model.provider === PROVIDER && model.api === ROUTING_API;
}

// --- Endpoint data --------------------------------------------------------

// Throughput/latency stats are only populated for authenticated requests.
function openRouterApiKey(): string | undefined {
  try {
    const auth = JSON.parse(readFileSync(AUTH_PATH, "utf8"));
    const creds = auth?.openrouter;
    if (creds?.type === "api_key" && typeof creds.key === "string" && creds.key.length > 0) {
      return creds.key;
    }
  } catch {
    // Fall through to the environment.
  }
  const fromEnv = process.env.OPENROUTER_API_KEY;
  return fromEnv && fromEnv.length > 0 ? fromEnv : undefined;
}

function authHeaders(): Record<string, string> {
  const key = openRouterApiKey();
  return key ? { Authorization: `Bearer ${key}` } : {};
}

let zdrList: Promise<Endpoint[]> | undefined;

function zdrEndpoints(): Promise<Endpoint[]> {
  if (!zdrList) {
    zdrList = fetch(ZDR_ENDPOINTS, { headers: authHeaders() })
      .then((response) => {
        if (!response.ok) throw new Error(`OpenRouter ZDR endpoint list returned ${response.status}`);
        return response.json();
      })
      .then((body) => {
        const data = (body as { data?: unknown }).data;
        if (!Array.isArray(data)) throw new Error("unexpected ZDR endpoint list shape");
        return data as Endpoint[];
      })
      .catch((error) => {
        zdrList = undefined;
        throw error;
      });
  }
  return zdrList;
}

function modelEndpoints(model: string): Promise<Endpoint[]> {
  const path = model.split("/").map(encodeURIComponent).join("/");
  return fetch(`${OPENROUTER_API}/models/${path}/endpoints`, { headers: authHeaders() })
    .then((response) => {
      if (!response.ok) throw new Error(`OpenRouter endpoint list returned ${response.status}`);
      return response.json();
    })
    .then((body) => {
      const endpoints = (body as { data?: { endpoints?: unknown } }).data?.endpoints;
      if (!Array.isArray(endpoints)) throw new Error("unexpected endpoint list shape");
      return endpoints as Endpoint[];
    });
}

interface EndpointData {
  endpoints: Endpoint[];
  /** ZDR endpoint tags for this model, or null when the ZDR list could not be fetched. */
  zdrTags: Set<string> | null;
}

async function loadEndpoints(model: string): Promise<EndpointData> {
  const [endpoints, zdr] = await Promise.all([
    modelEndpoints(model),
    // ZDR status is informational: still show the full endpoint list if it fails.
    zdrEndpoints().catch(() => undefined),
  ]);
  // The per-model response can use the canonical slug even when the requested
  // model ID is an alias, so key the ZDR list off the returned model ID.
  const endpointModel = endpoints.find((endpoint) => typeof endpoint.model_id === "string")?.model_id;
  const zdrTags = zdr
    ? new Set(
        zdr
          .filter((endpoint) => !endpointModel || endpoint.model_id === endpointModel)
          .map((endpoint) => String(endpoint.tag)),
      )
    : null;
  return { endpoints, zdrTags };
}

function estimatedCost(inputPerM: number, outputPerM: number, cacheReadPerM: number): number {
  const turns = CONTEXT_TOKENS / GROWTH_PER_CALL;
  const cacheTokens = (CONTEXT_TOKENS * (turns - 1)) / 2;
  const inputTokens = INPUT_SHARE * CONTEXT_TOKENS;
  const outputTokens = (1 - INPUT_SHARE) * CONTEXT_TOKENS;
  // Providers that report no cache-read price get no caching discount.
  const cachePrice = cacheReadPerM || inputPerM;
  return (cachePrice * cacheTokens + inputPerM * inputTokens + outputPerM * outputTokens) / 1e6;
}

/**
 * Tool-capable endpoints, cheapest first. All quantization levels and ZDR/non-ZDR
 * endpoints are included; the picker marks ZDR status per row.
 */
function buildRows(endpoints: Endpoint[], zdrTags: Set<string> | null): Row[] {
  const rows: Row[] = [];
  for (const endpoint of endpoints) {
    const params = Array.isArray(endpoint.supported_parameters) ? endpoint.supported_parameters : [];
    if (!params.includes("tools")) continue;

    const tag = typeof endpoint.tag === "string" ? endpoint.tag : "";
    if (!tag) continue;

    const quant = typeof endpoint.quantization === "string" ? endpoint.quantization : "unknown";
    const pricing = (endpoint.pricing ?? {}) as Record<string, unknown>;
    const input = Number(pricing.prompt ?? 0) * 1e6;
    const output = Number(pricing.completion ?? 0) * 1e6;
    const cacheRead = Number(pricing.input_cache_read ?? 0) * 1e6;
    const throughputStats = (endpoint.throughput_last_30m ?? {}) as Record<string, unknown>;
    const throughput: Record<string, number | null> = {};
    for (const [level, value] of Object.entries(throughputStats)) {
      if (!THROUGHPUT_PERCENTILE.test(level)) continue;
      const tokensPerSecond = Number(value);
      throughput[level] = Number.isFinite(tokensPerSecond) && tokensPerSecond > 0 ? tokensPerSecond : null;
    }

    rows.push({
      tag,
      provider: typeof endpoint.provider_name === "string" ? endpoint.provider_name : tag,
      quant: quant.toLowerCase(),
      zdr: zdrTags ? zdrTags.has(tag) : null,
      context: typeof endpoint.context_length === "number" ? endpoint.context_length : null,
      cost: estimatedCost(input, output, cacheRead),
      throughput,
    });
  }
  rows.sort((left, right) => left.cost - right.cost);
  return rows;
}

// --- Formatting -----------------------------------------------------------

function formatTokens(tokens: number | null): string {
  if (!tokens) return "?";
  if (tokens >= 1_000_000) return `${Number((tokens / 1_000_000).toFixed(1))}M`;
  if (tokens >= 1_000) return `${Math.round(tokens / 1_000)}K`;
  return String(tokens);
}

function formatCost(costUsd: number): string {
  const cost = costUsd * USD_TO_AUD;
  if (cost === 0) return "A$0";
  if (cost < 0.01) return `A$${cost.toFixed(4)}`;
  return `A$${cost.toFixed(cost < 1 ? 3 : 2)}`;
}

function formatThroughput(tokensPerSecond: number | null): string {
  if (tokensPerSecond === null) return "?";
  return String(Math.round(tokensPerSecond));
}

function formatZdr(zdr: boolean | null): string {
  if (zdr === null) return "?";
  return zdr ? "yes" : "no";
}

/** Percentile levels present in any row, ordered numerically (p50, p75, p90, p99). */
function throughputLevels(rows: Row[]): string[] {
  const levels = new Set<string>();
  for (const row of rows) {
    for (const level of Object.keys(row.throughput)) levels.add(level);
  }
  return [...levels].sort((left, right) => Number(left.slice(1)) - Number(right.slice(1)));
}

// --- Picker ---------------------------------------------------------------

class ProviderPicker implements Component, Focusable {
  private readonly input = new Input();
  private readonly border: DynamicBorder;
  private readonly all: Row[];
  private readonly currentTag: string | undefined;
  private visible: Row[] = [];
  private selected = 0;
  private isFocused = false;

  get focused(): boolean {
    return this.isFocused;
  }

  set focused(value: boolean) {
    this.isFocused = value;
    this.input.focused = value;
  }

  constructor(
    private readonly model: string,
    rows: Row[],
    currentTag: string | undefined,
    private readonly allowPin: boolean,
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly done: (tag: string | undefined) => void,
  ) {
    this.border = new DynamicBorder((text) => theme.fg("border", text));
    this.all = rows;
    this.currentTag = currentTag;
    this.refreshVisible();
  }

  /** Rows matching the search query. */
  private refreshVisible(): void {
    const query = this.input.getValue().trim();
    this.visible = query
      ? fuzzyFilter(this.all, query, (row) => `${row.provider} ${row.quant} ${row.tag}`)
      : this.all;

    const pinned = this.visible.findIndex((row) => row.tag === this.currentTag);
    if (pinned >= 0) this.selected = pinned;
    else this.selected = Math.min(Math.max(this.selected, 0), Math.max(0, this.visible.length - 1));
  }

  handleInput(data: string): void {
    const keybindings = getKeybindings();
    if (keybindings.matches(data, "tui.select.up")) {
      if (this.visible.length) this.selected = (this.selected - 1 + this.visible.length) % this.visible.length;
    } else if (keybindings.matches(data, "tui.select.down")) {
      if (this.visible.length) this.selected = (this.selected + 1) % this.visible.length;
    } else if (keybindings.matches(data, "tui.select.confirm")) {
      // View-only mode has nothing to select, so enter just closes the picker.
      this.done(this.allowPin ? this.visible[this.selected]?.tag : undefined);
    } else if (keybindings.matches(data, "tui.select.cancel")) {
      this.done(undefined);
    } else {
      const before = this.input.getValue();
      this.input.handleInput(data);
      if (this.input.getValue() !== before) this.refreshVisible();
    }
    this.tui.requestRender();
  }

  render(width: number): string[] {
    const theme = this.theme;
    const levels = throughputLevels(this.all);
    const header = [
      "provider",
      "quant",
      "zdr",
      "context",
      "est. cost",
      ...levels.map((level) => `${level} tok/s`),
    ];
    const lines = [...this.border.render(width)];
    lines.push(
      theme.fg(
        "accent",
        theme.bold(`OpenRouter endpoints — ${this.model}${this.allowPin ? "" : " (view only)"}`),
      ),
    );
    const filter = "all quants · tool-capable · cheapest first";
    lines.push(theme.fg("muted", this.allowPin ? filter : `${filter} · routing ignored by this transport`));
    lines.push("");
    lines.push(...this.input.render(width));
    lines.push("");

    if (this.visible.length === 0) {
      lines.push(theme.fg("muted", "  no matching endpoints"));
    } else {
      const start = Math.max(
        0,
        Math.min(this.selected - Math.floor(MAX_VISIBLE_ROWS / 2), this.visible.length - MAX_VISIBLE_ROWS),
      );
      const end = Math.min(start + MAX_VISIBLE_ROWS, this.visible.length);
      const cells = this.visible.map((row) => [
        row.provider,
        row.quant,
        formatZdr(row.zdr),
        formatTokens(row.context),
        formatCost(row.cost),
        ...levels.map((level) => formatThroughput(row.throughput[level] ?? null)),
      ]);
      const widths = header.map((title, index) =>
        Math.max(visibleWidth(title), ...cells.map((row) => visibleWidth(row[index] ?? ""))),
      );
      const format = (row: string[]) =>
        row.map((cell, index) => (index === row.length - 1 ? cell : cell.padEnd(widths[index]))).join("  ");

      lines.push(`  ${theme.fg("muted", format(header))}`);
      for (let index = start; index < end; index++) {
        const isSelected = index === this.selected;
        const isPinned = this.visible[index].tag === this.currentTag;
        const text = format(cells[index]);
        const cursor = isSelected ? theme.fg("accent", "→ ") : "  ";
        const marker = isPinned ? theme.fg("success", "✓ ") : "  ";
        lines.push(`${cursor}${marker}${isSelected ? theme.fg("accent", text) : text}`);
      }
      if (start > 0 || end < this.visible.length) {
        lines.push(theme.fg("dim", `  (${this.selected + 1}/${this.visible.length})`));
      }
    }

    lines.push("");
    lines.push(
      theme.fg(
        "dim",
        this.allowPin
          ? "type to filter · ↑↓ move · enter pin · esc cancel"
          : "type to filter · ↑↓ move · enter/esc close",
      ),
    );
    lines.push(...this.border.render(width));
    return lines.map((line) => truncateToWidth(line, width));
  }

  invalidate(): void {
    this.input.invalidate();
    this.border.invalidate();
  }
}

/** Run a request behind a cancellable spinner. Resolves undefined when cancelled or failed. */
async function load<T>(
  ctx: ExtensionContext,
  message: string,
  task: (signal: AbortSignal) => Promise<T>,
): Promise<T | undefined> {
  let failure: unknown;
  const result = await ctx.ui.custom<T | undefined>((tui, theme, _keybindings, done) => {
    let settled = false;
    const finish = (value: T | undefined) => {
      if (settled) return;
      settled = true;
      done(value);
    };
    const loader = new BorderedLoader(tui, theme, message);
    loader.onAbort = () => finish(undefined);
    task(loader.signal).then(finish, (error: unknown) => {
      failure = error;
      finish(undefined);
    });
    return loader;
  });
  if (failure && !(failure instanceof Error && failure.name === "AbortError")) {
    ctx.ui.notify(`OpenRouter: ${failure instanceof Error ? failure.message : String(failure)}`, "error");
  }
  return result;
}

// --- Status / warnings ----------------------------------------------------

function refreshStatus(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  const model = ctx.model;
  if (!model || model.provider !== PROVIDER) {
    ctx.ui.setStatus("openrouter", undefined);
    return;
  }
  // A pin on a non-routing transport would be ignored, so never claim it is active.
  const pin = isRoutingModel(model) ? pins[model.id] : undefined;
  if (pin) {
    ctx.ui.setStatus("openrouter", `or: ${pin.provider} ${pin.quant}`);
  } else {
    ctx.ui.setStatus("openrouter", isRoutingModel(model) ? "or: unpinned" : undefined);
  }
}

/** Routing-capable OpenRouter models cannot be used until a provider is pinned. */
function warnIfUnpinned(ctx: ExtensionContext): void {
  const model = ctx.model;
  if (!isRoutingModel(model) || pins[model.id]) return;
  if (ctx.hasUI) ctx.ui.notify(`No OpenRouter provider pinned for ${model.id}. Run /or-model to pin one.`, "error");
}

// --- Extension ------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    pins = loadPins();
    refreshStatus(ctx);
    warnIfUnpinned(ctx);
  });

  pi.on("model_select", (_event, ctx) => {
    refreshStatus(ctx);
    warnIfUnpinned(ctx);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setStatus("openrouter", undefined);
  });

  pi.registerCommand("or-model", {
    description: "View OpenRouter endpoints and pin the active one where supported",
    handler: async (_args, ctx) => {
      const model = ctx.model;
      if (!model || model.provider !== PROVIDER) {
        ctx.ui.notify("/or-model: select an OpenRouter model first.", "error");
        return;
      }
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/or-model needs the interactive terminal UI.", "error");
        return;
      }

      // Only openai-completions honours OpenRouter's `provider` routing field;
      // other transports can still browse endpoints, but cannot be pinned.
      const canPin = isRoutingModel(model);

      const data = await load(ctx, `Fetching endpoints for ${model.id}…`, () => loadEndpoints(model.id));
      if (!data) return;

      const rows = buildRows(data.endpoints, data.zdrTags);
      if (rows.length === 0) {
        ctx.ui.notify(`No tool-capable endpoints for ${model.id}.`, "warning");
        return;
      }

      const tag = await ctx.ui.custom<string | undefined>(
        (tui, theme, _keybindings, done) =>
          new ProviderPicker(
            model.id,
            rows,
            canPin ? pins[model.id]?.tag : undefined,
            canPin,
            tui,
            theme,
            done,
          ),
      );
      if (!tag || !canPin) return;

      const row = rows.find((candidate) => candidate.tag === tag);
      if (!row) return;

      pins[model.id] = { tag: row.tag, provider: row.provider, quant: row.quant, pinnedAt: Date.now() };
      savePins(pins);
      ctx.ui.notify(`${model.id} → ${row.provider} (${row.quant})`, "info");
      refreshStatus(ctx);
    },
  });

  pi.on("before_provider_headers", (event, ctx) => {
    if (ctx.model?.provider !== PROVIDER) return;
    event.headers["x-openrouter-metadata"] = "enabled";
  });

  pi.on("before_provider_request", (event, ctx) => {
    const model = ctx.model;
    if (!isRoutingModel(model)) return;

    const pin = pins[model.id];
    if (!pin) {
      throw new Error(`No OpenRouter provider pinned for ${model.id}. Run /or-model to pin an endpoint.`);
    }

    const payload = event.payload as { provider?: Record<string, unknown> } | null;
    if (!payload || typeof payload !== "object") return;
    payload.provider = { only: [pin.tag], allow_fallbacks: false };
    return payload;
  });
}
