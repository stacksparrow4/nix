import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// Ports the algorithm from openrouter_clean_providers.py: scrape a model's
// OpenRouter page for its per-endpoint data policies and pricing, drop every
// endpoint quantized below fp8 or that trains on / retains prompts, rank the
// survivors by the estimated cost of a cache-friendly 100k-token-context
// conversation, and pin the request to that provider set.
//
// The cheapest clean provider is preferred; because the allowed set is bounded
// with `only`, a fallback can only ever reach another clean provider — never a
// training/retaining one. `data_collection: "deny"` backs the endpoint-level
// policy check with OpenRouter's own provider-level filter.
//
// The scrape runs once per model per Pi process and is memoized in memory, so
// Pi must be restarted to pick up new prices or providers.

const MODEL_PAGE = "https://openrouter.ai/";
const USER_AGENT =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36";

// --- Estimated-cost model (mirrors the Python script) ---------------------
// Derived from a 31-call agentic session: 32,350 fresh input tokens and 25,030
// output tokens, scaled to a conversation whose final context is 100k tokens
// and assuming perfect prompt caching.
const CONTEXT_TOKENS = 100_000;
const EMPIRICAL_INPUT_TOKENS = 32_350;
const EMPIRICAL_OUTPUT_TOKENS = 25_030;
const EMPIRICAL_CALLS = 31;
const GROWTH_PER_CALL = (EMPIRICAL_INPUT_TOKENS + EMPIRICAL_OUTPUT_TOKENS) / EMPIRICAL_CALLS;
const INPUT_SHARE = EMPIRICAL_INPUT_TOKENS / (EMPIRICAL_INPUT_TOKENS + EMPIRICAL_OUTPUT_TOKENS);

// Only keep fp8 and above (drop fp4 and unrecognized/'unknown' labels).
const MIN_QUANT_BITS = 8;

interface Routing {
  only: string[];
  order: string[];
  quantizations: string[];
  allow_fallbacks: boolean;
  data_collection: "deny";
}

type Endpoint = Record<string, any>;

// model id -> in-flight/complete routing (undefined when no clean endpoint).
const cache = new Map<string, Promise<Routing | undefined>>();
const warned = new Set<string>();

// --- On-disk routing cache ------------------------------------------------
// The scrape is best-effort, so when it fails we fall back to the last routing
// that scraped cleanly for this model rather than OpenRouter's default
// (unfiltered) provider set. One JSON file per model, mirroring the footer's
// per-source usage snapshots; discrete files mean a concurrent writer can only
// ever clobber an equally-good entry for the same model.
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
  } catch {
    // No cache yet, or unreadable.
  }
  return undefined;
}

function writeRoutingCache(model: string, routing: Routing | undefined): void {
  const path = routingCachePath(model);
  try {
    if (routing) {
      const entry: RoutingCacheEntry = { routing, fetchedAt: Date.now() };
      writeFileSync(path, JSON.stringify(entry));
    } else {
      // A clean scrape that found no qualifying endpoint must not leave a stale
      // entry behind for the next failure to resurrect.
      rmSync(path, { force: true });
    }
  } catch {
    // Best-effort; a write failure only costs a future cold start its fallback.
  }
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

/** Substring of a balanced [...] starting at `start`, ignoring brackets inside strings. */
function matchBracket(text: string, start: number): string {
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const char = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') inString = false;
    } else if (char === '"') {
      inString = true;
    } else if (char === "[") {
      depth++;
    } else if (char === "]") {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  throw new Error("unbalanced brackets while parsing flight payload");
}

/** Next.js streams server data via self.__next_f.push([1,"<json string>"]) calls. */
function flightPayload(html: string): string {
  const chunkRe = /self\.__next_f\.push\(\[1,("[\s\S]*?")\]\)/g;
  let flight = "";
  for (const match of html.matchAll(chunkRe)) {
    try {
      flight += JSON.parse(match[1]);
    } catch {
      // Ignore a malformed chunk; the data may still arrive in another one.
    }
  }
  return flight;
}

/** Dehydrated React-Query array of endpoints carrying per-endpoint status and stats. */
function findStatsArray(flight: string): Endpoint[] | null {
  const anchor = flight.indexOf('"stats":{"endpoint_id"');
  if (anchor === -1) return null;
  const key = '"state":{"data":[';
  const keyIndex = flight.lastIndexOf(key, anchor);
  if (keyIndex === -1) return null;
  const start = flight.indexOf("[", keyIndex);
  if (start === -1) return null;
  const array = JSON.parse(matchBracket(flight, start));
  if (
    Array.isArray(array) &&
    array.length > 0 &&
    typeof array[0] === "object" &&
    array[0] !== null &&
    "data_policy" in array[0] &&
    "stats" in array[0]
  ) {
    return array as Endpoint[];
  }
  return null;
}

function extractEndpoints(html: string, model: string): Endpoint[] {
  const flight = flightPayload(html);
  const stats = findStatsArray(flight);
  if (stats) return stats;

  // Fallback: the stats-less variantGroups block.
  const key = '"variantGroups":';
  const keyIndex = flight.indexOf(key);
  if (keyIndex === -1) throw new Error(`no endpoint data found for ${model}`);
  const groups = JSON.parse(matchBracket(flight, flight.indexOf("[", keyIndex)));
  const standard = (groups as Endpoint[]).filter((group) => group.variant === "standard");
  if (standard.length === 0) throw new Error(`no standard variant group for ${model}`);
  return standard[0].endpoints as Endpoint[];
}

/** Base provider slug OpenRouter routing accepts (endpoint slugs carry a /quant suffix). */
function baseSlug(endpoint: Endpoint): string {
  const info = endpoint.provider_info as { slug?: unknown } | undefined;
  if (info && typeof info.slug === "string" && info.slug) return info.slug;
  const slug = typeof endpoint.provider_slug === "string" ? endpoint.provider_slug : "";
  return slug.split("/")[0];
}

function buildRouting(endpoints: Endpoint[]): Routing | undefined {
  const ranked: { base: string; quant: string; cost: number }[] = [];
  for (const endpoint of endpoints) {
    const quant = typeof endpoint.quantization === "string" ? endpoint.quantization : "unknown";
    if ((quantBits(quant) ?? 0) < MIN_QUANT_BITS) continue;

    const policy = (endpoint.data_policy ?? {}) as { training?: unknown; retainsPrompts?: unknown };
    if (policy.training || policy.retainsPrompts) continue;

    const pricing = (endpoint.pricing ?? {}) as Record<string, unknown>;
    const input = Number(pricing.prompt ?? 0) * 1e6;
    const output = Number(pricing.completion ?? 0) * 1e6;
    const cacheRead = Number(pricing.input_cache_read ?? 0) * 1e6;

    const base = baseSlug(endpoint);
    if (!base) continue;
    ranked.push({ base, quant: quant.toLowerCase(), cost: estimatedCost(input, output, cacheRead) });
  }
  if (ranked.length === 0) return undefined;

  // Cheapest estimated cost first; dedupe base slugs while preserving that order.
  ranked.sort((a, b) => a.cost - b.cost);
  const only: string[] = [];
  const quantizations = new Set<string>();
  for (const row of ranked) {
    if (!only.includes(row.base)) only.push(row.base);
    quantizations.add(row.quant);
  }

  return {
    only,
    order: [...only],
    quantizations: [...quantizations],
    allow_fallbacks: true,
    data_collection: "deny",
  };
}

async function computeRouting(model: string): Promise<Routing | undefined> {
  const response = await fetch(`${MODEL_PAGE}${model}`, { headers: { "user-agent": USER_AGENT } });
  if (!response.ok) throw new Error(`OpenRouter model page returned ${response.status}`);
  const endpoints = extractEndpoints(await response.text(), model);
  const routing = buildRouting(endpoints);
  // Only reached on a fully successful scrape (parsing included); a failure
  // leaves the previous entry intact for the fallback path below.
  writeRoutingCache(model, routing);
  return routing;
}

/** Compute once per model per process; a failure is not cached so it can retry. */
function routingFor(model: string): Promise<Routing | undefined> {
  const cached = cache.get(model);
  if (cached) return cached;
  const promise = computeRouting(model).catch((error) => {
    cache.delete(model);
    // Network/scrape failure: prefer the last routing that scraped cleanly over
    // OpenRouter's default provider set. Left uncached so the next request
    // still retries the scrape and can pick up fresh pricing/providers.
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

  // Ask OpenRouter to report which endpoint actually served each request (the
  // footer reads the resulting `openrouter_metadata` off the final stream
  // chunk). Independent of routing, so it also covers a fallback to the default
  // provider set.
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
