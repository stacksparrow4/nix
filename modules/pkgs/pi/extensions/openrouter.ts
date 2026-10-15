import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// The ZDR list is exactly the model pages' `!(training || retainsPrompts)` set;
// `zdr`/`data_collection` also make OpenRouter enforce it server-side.

const ZDR_ENDPOINTS = "https://openrouter.ai/api/v1/endpoints/zdr";

// Derived from a 31-call agentic session: 32,350 fresh input and 25,030 output
// tokens, scaled to a 100k-token final context with perfect prompt caching.
const CONTEXT_TOKENS = 100_000;
const EMPIRICAL_INPUT_TOKENS = 32_350;
const EMPIRICAL_OUTPUT_TOKENS = 25_030;
const EMPIRICAL_CALLS = 31;
const GROWTH_PER_CALL = (EMPIRICAL_INPUT_TOKENS + EMPIRICAL_OUTPUT_TOKENS) / EMPIRICAL_CALLS;
const INPUT_SHARE = EMPIRICAL_INPUT_TOKENS / (EMPIRICAL_INPUT_TOKENS + EMPIRICAL_OUTPUT_TOKENS);

const MIN_QUANT_BITS = 8;

interface Routing {
  only: string[];
  order: string[];
  quantizations: string[];
  allow_fallbacks: boolean;
  zdr: true;
  data_collection: "deny";
}

type Endpoint = Record<string, any>;

const cache = new Map<string, Promise<Routing | undefined>>();
const warned = new Set<string>();

interface RoutingCacheEntry {
  routing: Routing;
  fetchedAt: number;
}

function routingCachePath(model: string): string {
  return join(getAgentDir(), "sessions", `openrouter-routing-${encodeURIComponent(model)}.json`);
}

function loadRoutingCache(model: string): Routing | undefined {
  try {
    const parsed = JSON.parse(readFileSync(routingCachePath(model), "utf8"));
    if (parsed && parsed.routing && Array.isArray(parsed.routing.only)) {
      return parsed.routing as Routing;
    }
  } catch {}
  return undefined;
}

function writeRoutingCache(model: string, routing: Routing | undefined): void {
  const path = routingCachePath(model);
  try {
    if (routing) {
      const entry: RoutingCacheEntry = { routing, fetchedAt: Date.now() };
      writeFileSync(path, JSON.stringify(entry));
    } else {
      // A clean fetch with no qualifying endpoint must not leave a stale entry
      // behind for the next failure to resurrect.
      rmSync(path, { force: true });
    }
  } catch {}
}

function quantBits(quant: unknown): number | null {
  if (typeof quant !== "string" || quant.length === 0) return null;
  const match = /^(?:fp|bf|int)(\d+)/.exec(quant.toLowerCase());
  return match ? Number(match[1]) : null;
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

function endpointSlug(endpoint: Endpoint): string {
  const tag = typeof endpoint.tag === "string" ? endpoint.tag : "";
  if (tag) return tag;
  return typeof endpoint.provider_name === "string" ? endpoint.provider_name : "";
}

function buildRouting(endpoints: Endpoint[]): Routing | undefined {
  const ranked: { slug: string; quant: string; cost: number }[] = [];
  for (const endpoint of endpoints) {
    const quant = typeof endpoint.quantization === "string" ? endpoint.quantization : "unknown";
    if ((quantBits(quant) ?? 0) < MIN_QUANT_BITS) continue;

    const pricing = (endpoint.pricing ?? {}) as Record<string, unknown>;
    const input = Number(pricing.prompt ?? 0) * 1e6;
    const output = Number(pricing.completion ?? 0) * 1e6;
    const cacheRead = Number(pricing.input_cache_read ?? 0) * 1e6;

    const slug = endpointSlug(endpoint);
    if (!slug) continue;
    ranked.push({ slug, quant: quant.toLowerCase(), cost: estimatedCost(input, output, cacheRead) });
  }
  if (ranked.length === 0) return undefined;

  ranked.sort((a, b) => a.cost - b.cost);
  const only: string[] = [];
  const quantizations = new Set<string>();
  for (const row of ranked) {
    if (!only.includes(row.slug)) only.push(row.slug);
    quantizations.add(row.quant);
  }

  return {
    only,
    order: [...only],
    quantizations: [...quantizations],
    allow_fallbacks: true,
    zdr: true,
    data_collection: "deny",
  };
}

let zdrList: Promise<Endpoint[]> | undefined;

function zdrEndpoints(): Promise<Endpoint[]> {
  if (!zdrList) {
    zdrList = fetch(ZDR_ENDPOINTS)
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

async function computeRouting(model: string): Promise<Routing | undefined> {
  const endpoints = (await zdrEndpoints()).filter((endpoint) => endpoint.model_id === model);
  const routing = buildRouting(endpoints);
  writeRoutingCache(model, routing);
  return routing;
}

function routingFor(model: string): Promise<Routing | undefined> {
  const cached = cache.get(model);
  if (cached) return cached;
  const promise = computeRouting(model).catch((error) => {
    cache.delete(model);
    const fallback = loadRoutingCache(model);
    if (fallback) return fallback;
    throw error;
  });
  cache.set(model, promise);
  return promise;
}

function warnOnce(model: string, error: unknown, ctx: ExtensionContext): void {
  if (warned.has(model)) return;
  warned.add(model);
  const message = error instanceof Error ? error.message : String(error);
  if (ctx.hasUI) ctx.ui.notify(`OpenRouter routing for ${model}: ${message}`, "warning");
}

function prefetch(model: string | undefined, ctx: ExtensionContext): void {
  if (!model) return;
  void routingFor(model).catch((error) => warnOnce(model, error, ctx));
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.model?.provider === "openrouter") prefetch(ctx.model.id, ctx);
  });

  pi.on("model_select", (event, ctx) => {
    if (event.model.provider === "openrouter") prefetch(event.model.id, ctx);
  });

  // Report which endpoint served each request (read by the footer).
  pi.on("before_provider_headers", (event, ctx) => {
    if (ctx.model?.provider !== "openrouter") return;
    event.headers["x-openrouter-metadata"] = "enabled";
  });

  pi.on("before_provider_request", async (event, ctx) => {
    const model = ctx.model;
    if (!model || model.provider !== "openrouter" || model.api !== "openai-completions") return;
    const payload = event.payload as { provider?: Record<string, unknown> } | null;
    if (!payload || typeof payload !== "object") return;

    let routing: Routing | undefined;
    try {
      routing = await routingFor(model.id);
    } catch (error) {
      warnOnce(model.id, error, ctx);
      return;
    }
    if (!routing) return;

    payload.provider = { ...payload.provider, ...routing };
    return payload;
  });
}
