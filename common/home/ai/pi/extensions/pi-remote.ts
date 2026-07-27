import { Buffer } from "node:buffer";
import { connect } from "node:net";
import { basename } from "node:path";
import {
  type AutocompleteProviderFactory,
  type BashOperations,
  createBashTool,
  createBashToolDefinition,
  createEditToolDefinition,
  createReadToolDefinition,
  createWriteToolDefinition,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import {
  type AutocompleteItem,
  type AutocompleteProvider,
  type AutocompleteSuggestions,
  Text,
} from "@earendil-works/pi-tui";
import { Type } from "typebox";


const SOCKET_PATH = "/tmp/pi-remote/pi.sock";
const FULL_REMOTE = process.env.PI_REMOTE_FILE_TOOLS === "1";
const SPECIFIED_REMOTE = process.env.PI_SPECIFIED_REMOTE === "1";
const TOOL_NAME = FULL_REMOTE ? "bash" : "command";
const DEFAULT_TIMEOUT_SECONDS = 10;
const REMOTE_FILE_OP_TIMEOUT_SECONDS = 30;

interface ExecOptions {
  timeout?: number; // seconds
  signal?: AbortSignal;
  onData?: (data: Buffer, kind: "stdout" | "stderr") => void;
}

interface ExecResult {
  exitCode: number | null;
  stdout: Buffer;
  stderr: Buffer;
  timedOut: boolean;
  aborted: boolean;
  error?: string;
}

function bridgeExec(command: string, options: ExecOptions = {}): Promise<ExecResult> {
  return new Promise((resolve, reject) => {
    const sock = connect(SOCKET_PATH);
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    let exitCode: number | null = null;
    let serverError: string | undefined;
    let timedOut = false;
    let settled = false;
    let buf = Buffer.alloc(0);

    const cleanup = () => {
      options.signal?.removeEventListener("abort", onAbort);
      try {
        sock.destroy();
      } catch {
        // ignore
      }
    };

    const settle = (result: ExecResult | Error) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (result instanceof Error) reject(result);
      else resolve(result);
    };

    const onAbort = () => {
      // Half-close from our side so the server kills the child.
      try {
        sock.end();
      } catch {
        // ignore
      }
      settle({
        exitCode: null,
        stdout: Buffer.concat(stdoutChunks),
        stderr: Buffer.concat(stderrChunks),
        timedOut: false,
        aborted: true,
      });
    };

    if (options.signal) {
      if (options.signal.aborted) {
        sock.destroy();
        settle({
          exitCode: null,
          stdout: Buffer.alloc(0),
          stderr: Buffer.alloc(0),
          timedOut: false,
          aborted: true,
        });
        return;
      }
      options.signal.addEventListener("abort", onAbort, { once: true });
    }

    sock.once("connect", () => {
      const req = JSON.stringify({
        command,
        timeout: options.timeout ?? null,
      });
      sock.write(`${req}\n`);
    });

    const handleLine = (line: string) => {
      if (!line) return;
      let msg: { type?: string; data?: string; code?: number; message?: string };
      try {
        msg = JSON.parse(line);
      } catch {
        serverError = `bad json from bridge: ${line.slice(0, 200)}`;
        return;
      }
      if (msg.type === "stdout" || msg.type === "stderr") {
        const data = Buffer.from(msg.data ?? "", "base64");
        if (msg.type === "stdout") stdoutChunks.push(data);
        else stderrChunks.push(data);
        options.onData?.(data, msg.type);
      } else if (msg.type === "exit") {
        exitCode = typeof msg.code === "number" ? msg.code : null;
      } else if (msg.type === "error") {
        serverError = msg.message ?? "bridge error";
        if (typeof serverError === "string" && /^timeout/i.test(serverError)) {
          timedOut = true;
        }
      }
    };

    sock.on("data", (chunk: Buffer) => {
      buf = buf.length === 0 ? chunk : Buffer.concat([buf, chunk]);
      while (true) {
        const nl = buf.indexOf(0x0a);
        if (nl < 0) break;
        const line = buf.subarray(0, nl).toString("utf-8");
        buf = buf.subarray(nl + 1);
        handleLine(line);
      }
    });

    sock.on("error", (err: Error) => {
      settle(new Error(`bridge socket error (${SOCKET_PATH}): ${err.message}`));
    });

    sock.on("close", () => {
      if (buf.length > 0) {
        handleLine(buf.toString("utf-8"));
        buf = Buffer.alloc(0);
      }
      settle({
        exitCode,
        stdout: Buffer.concat(stdoutChunks),
        stderr: Buffer.concat(stderrChunks),
        timedOut,
        aborted: false,
        error: serverError,
      });
    });
  });
}

// File operations
// ------------------------------------------------------------

function shQuote(s: string): string {
  return `'${s.split("'").join(`'\\''`)}'`;
}

async function runFileOp(command: string): Promise<ExecResult> {
  const res = await bridgeExec(command, { timeout: REMOTE_FILE_OP_TIMEOUT_SECONDS });
  if (res.aborted) throw new Error("aborted");
  if (res.timedOut) throw new Error(`timeout after ${REMOTE_FILE_OP_TIMEOUT_SECONDS}s`);
  if (res.error && res.exitCode === null) throw new Error(res.error);
  return res;
}

function opError(res: ExecResult, fallback: string): Error {
  const stderr = res.stderr.toString("utf-8").trim();
  return new Error(stderr || fallback);
}

async function remoteReadFile(path: string): Promise<Buffer> {
  const res = await runFileOp(`base64 < ${shQuote(path)}`);
  if (res.exitCode !== 0) throw opError(res, `Failed to read ${path}`);
  return Buffer.from(res.stdout.toString("utf-8").replace(/\s+/g, ""), "base64");
}

async function remoteWriteFile(path: string, content: string): Promise<void> {
  const b64 = Buffer.from(content, "utf-8").toString("base64");
  const res = await runFileOp(`printf %s ${shQuote(b64)} | base64 -d > ${shQuote(path)}`);
  if (res.exitCode !== 0) throw opError(res, `Failed to write ${path}`);
}

async function remoteMkdir(dir: string): Promise<void> {
  const res = await runFileOp(`mkdir -p ${shQuote(dir)}`);
  if (res.exitCode !== 0) throw opError(res, `Failed to create directory ${dir}`);
}

async function remoteAccess(path: string, mode: "r" | "rw"): Promise<void> {
  const test =
    mode === "rw"
      ? `[ -r ${shQuote(path)} ] && [ -w ${shQuote(path)} ]`
      : `[ -r ${shQuote(path)} ]`;
  const res = await runFileOp(test);
  if (res.exitCode !== 0) {
    const err = new Error(`Cannot access ${path}`) as Error & { code?: string };
    err.code = "ENOENT";
    throw err;
  }
}

let cachedRemotePwd: Promise<string> | undefined;

function remotePwdCached(): Promise<string> {
  cachedRemotePwd ??= remotePwd();
  return cachedRemotePwd;
}

async function remotePwd(): Promise<string> {
  try {
    const res = await bridgeExec("pwd", { timeout: REMOTE_FILE_OP_TIMEOUT_SECONDS });
    const out = res.stdout.toString("utf-8").trim();
    if (res.exitCode === 0 && out) return out;
  } catch {
    // fall through to default
  }
  return "/";
}

/**
 * Read the context file sitting directly in the bridge's cwd. Pi discovers context files relative
 * to its own cwd, which is not where tools run, so it never finds this one. Parent directories are
 * deliberately not searched.
 */
async function remoteContextFile(): Promise<string | undefined> {
  try {
    const res = await bridgeExec("[ -f ./AGENTS.md ] && base64 < ./AGENTS.md", {
      timeout: REMOTE_FILE_OP_TIMEOUT_SECONDS,
    });
    if (res.exitCode !== 0) return undefined;
    const content = Buffer.from(res.stdout.toString("utf-8").replace(/\s+/g, ""), "base64").toString("utf-8");
    if (content.trim()) return content;
  } catch {
    return undefined;
  }

  return undefined;
}

function createBridgeBashOps(): BashOperations {
  return {
    exec: async (command, _cwd, { onData, signal, timeout }) => {
      const result = await bridgeExec(command, {
        timeout,
        signal,
        onData: (chunk) => onData(chunk),
      });
      if (result.aborted) {
        throw new Error("aborted");
      }
      if (result.timedOut) {
        throw new Error(`timeout:${timeout ?? ""}`);
      }
      if (result.error && result.exitCode === null) {
        throw new Error(result.error);
      }
      return { exitCode: result.exitCode };
    },
  };
}

// Remote path autocomplete
// ------------------------------------------------------------
// Pi's built-in autocomplete resolves file paths against the filesystem of the
// process running the TUI (the pi sandbox), but tools and files actually live in
// the bridge's context (the tool/remote sandbox). This provider forwards plain
// Tab path completion over the same bridge the file tools use, so it reflects the
// real working tree. Slash-command and @-attachment completions are left to the
// built-in provider. The prefix parsing and value formatting mirror pi's own
// CombinedAutocompleteProvider so the built-in applyCompletion can be reused.

const PATH_DELIMITERS = new Set([" ", "\t", '"', "'", "="]);

function toDisplayPath(value: string): string {
  return value.replace(/\\/g, "/");
}

function findLastDelimiter(text: string): number {
  for (let i = text.length - 1; i >= 0; i -= 1) {
    if (PATH_DELIMITERS.has(text[i] ?? "")) return i;
  }
  return -1;
}

function findUnclosedQuoteStart(text: string): number | null {
  let inQuotes = false;
  let quoteStart = -1;
  for (let i = 0; i < text.length; i += 1) {
    if (text[i] === '"') {
      inQuotes = !inQuotes;
      if (inQuotes) quoteStart = i;
    }
  }
  return inQuotes ? quoteStart : null;
}

function isTokenStart(text: string, index: number): boolean {
  return index === 0 || PATH_DELIMITERS.has(text[index - 1] ?? "");
}

function extractQuotedPrefix(text: string): string | null {
  const quoteStart = findUnclosedQuoteStart(text);
  if (quoteStart === null) return null;
  if (quoteStart > 0 && text[quoteStart - 1] === "@") {
    if (!isTokenStart(text, quoteStart - 1)) return null;
    return text.slice(quoteStart - 1);
  }
  if (!isTokenStart(text, quoteStart)) return null;
  return text.slice(quoteStart);
}

function parsePathPrefix(prefix: string): { rawPrefix: string; isAtPrefix: boolean; isQuotedPrefix: boolean } {
  if (prefix.startsWith('@"')) return { rawPrefix: prefix.slice(2), isAtPrefix: true, isQuotedPrefix: true };
  if (prefix.startsWith('"')) return { rawPrefix: prefix.slice(1), isAtPrefix: false, isQuotedPrefix: true };
  if (prefix.startsWith("@")) return { rawPrefix: prefix.slice(1), isAtPrefix: true, isQuotedPrefix: false };
  return { rawPrefix: prefix, isAtPrefix: false, isQuotedPrefix: false };
}

function buildCompletionValue(path: string, isQuotedPrefix: boolean): string {
  const needsQuotes = isQuotedPrefix || path.includes(" ");
  return needsQuotes ? `"${path}"` : path;
}

function extractPathPrefix(text: string, forceExtract: boolean): string | null {
  const quotedPrefix = extractQuotedPrefix(text);
  if (quotedPrefix) return quotedPrefix;
  const lastDelimiterIndex = findLastDelimiter(text);
  const pathPrefix = lastDelimiterIndex === -1 ? text : text.slice(lastDelimiterIndex + 1);
  if (forceExtract) return pathPrefix;
  if (pathPrefix.includes("/") || pathPrefix.startsWith(".") || pathPrefix.startsWith("~/")) return pathPrefix;
  if (pathPrefix === "" && text.endsWith(" ")) return pathPrefix;
  return null;
}

// Split a raw path prefix into the directory portion (kept for display, always
// ends with "/" when non-empty) and the trailing filter/query segment.
function splitPathPrefix(rawPrefix: string): { dirDisplay: string; filter: string } {
  const p = toDisplayPath(rawPrefix);
  if (p === "~") return { dirDisplay: "~/", filter: "" };
  const idx = p.lastIndexOf("/");
  if (idx === -1) return { dirDisplay: "", filter: p };
  return { dirDisplay: p.slice(0, idx + 1), filter: p.slice(idx + 1) };
}

// Turn a display directory into a shell argument evaluated in the bridge context.
function remoteDirArg(dirDisplay: string): string {
  if (dirDisplay === "") return ".";
  if (dirDisplay.startsWith("~/")) return `"$HOME"/${shQuote(dirDisplay.slice(2))}`;
  return shQuote(dirDisplay);
}

interface RemoteEntry {
  path: string; // relative to dirDisplay
  isDirectory: boolean;
}

// Parse newline-separated `ls -p` output (dirs carry a trailing slash).
function parseListing(output: string): RemoteEntry[] {
  return output
    .split("\n")
    .map((line) => toDisplayPath(line.replace(/\r$/, "")))
    .filter(Boolean)
    .map((line) => {
      const isDirectory = line.endsWith("/");
      return { path: isDirectory ? line.slice(0, -1) : line, isDirectory };
    })
    .filter((e) => e.path && e.path !== ".git" && !e.path.startsWith(".git/") && !e.path.includes("/.git/"));
}

function entriesToItems(entries: RemoteEntry[], dirDisplay: string, isQuotedPrefix: boolean): AutocompleteItem[] {
  const items: AutocompleteItem[] = [];
  for (const { path: relativePath, isDirectory } of entries) {
    const displayPath = toDisplayPath(dirDisplay + relativePath);
    const pathValue = isDirectory ? `${displayPath}/` : displayPath;
    items.push({
      value: buildCompletionValue(pathValue, isQuotedPrefix),
      label: basename(relativePath) + (isDirectory ? "/" : ""),
    });
  }
  return items;
}

// List a single directory level in the bridge context.
async function remoteListDir(dirDisplay: string, signal: AbortSignal): Promise<RemoteEntry[]> {
  try {
    // -1 one per line, -A hidden but not . / .., -p mark dirs with /, -L follow symlinks.
    const res = await bridgeExec(`ls -1ApL -- ${remoteDirArg(dirDisplay)} 2>/dev/null`, {
      timeout: REMOTE_FILE_OP_TIMEOUT_SECONDS,
      signal,
    });
    if (res.aborted || res.exitCode !== 0) return [];
    return parseListing(res.stdout.toString("utf-8"));
  } catch {
    return [];
  }
}

async function shallowSuggestions(
  dirDisplay: string,
  filter: string,
  isQuotedPrefix: boolean,
  signal: AbortSignal,
): Promise<AutocompleteItem[]> {
  const entries = await remoteListDir(dirDisplay, signal);
  let filtered = entries;
  if (filter) {
    const lower = filter.toLowerCase();
    filtered = entries.filter((e) => e.path.toLowerCase().startsWith(lower));
  }
  filtered.sort((a, b) => {
    if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.path.localeCompare(b.path);
  });
  return entriesToItems(filtered, dirDisplay, isQuotedPrefix);
}

// Wrap the built-in provider so Tab path completion resolves in the bridge context.
const createRemoteAutocompleteProvider: AutocompleteProviderFactory = (
  current: AutocompleteProvider,
): AutocompleteProvider => ({
  triggerCharacters: current.triggerCharacters,

  async getSuggestions(lines, cursorLine, cursorCol, options): Promise<AutocompleteSuggestions | null> {
    const currentLine = lines[cursorLine] || "";
    const textBeforeCursor = currentLine.slice(0, cursorCol);

    // Slash commands are pi-local; leave them to the built-in provider.
    if (!options.force && textBeforeCursor.startsWith("/")) {
      return current.getSuggestions(lines, cursorLine, cursorCol, options);
    }

    const pathMatch = extractPathPrefix(textBeforeCursor, options.force ?? false);
    if (pathMatch === null) return null;

    const { rawPrefix, isAtPrefix, isQuotedPrefix } = parsePathPrefix(pathMatch);
    // @-attachments are pi-local; leave them to the built-in provider.
    if (isAtPrefix) return current.getSuggestions(lines, cursorLine, cursorCol, options);

    const { dirDisplay, filter } = splitPathPrefix(rawPrefix);
    const items = await shallowSuggestions(dirDisplay, filter, isQuotedPrefix, options.signal);
    if (items.length === 0) return null;
    return { items, prefix: pathMatch };
  },

  applyCompletion: (lines, cursorLine, cursorCol, item, prefix) =>
    current.applyCompletion(lines, cursorLine, cursorCol, item, prefix),

  shouldTriggerFileCompletion: current.shouldTriggerFileCompletion
    ? (lines, cursorLine, cursorCol) => current.shouldTriggerFileCompletion!(lines, cursorLine, cursorCol)
    : undefined,
});

export default async function(pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    const input = event.input;
    if (event.toolName === TOOL_NAME && input && input.timeout === undefined) {
      input.timeout = DEFAULT_TIMEOUT_SECONDS;
    }
    return undefined;
  });

  const builtIn = createBashToolDefinition("/");
  const originalRenderResult = builtIn.renderResult;
  const bridgeTool = createBashTool("/", { operations: createBridgeBashOps() });

  pi.registerTool({
    ...builtIn,
    name: TOOL_NAME,
    label: TOOL_NAME,
    description: `Execute a ${FULL_REMOTE ? "bash " : ""}command. Returns stdout and stderr. Output may be truncated if it is too long. If no timeout is given, a default of ${DEFAULT_TIMEOUT_SECONDS} seconds is applied.`,
    promptSnippet: FULL_REMOTE ? "Execute bash commands" : "Execute commands",
    parameters: Type.Object({
      command: Type.String({ description: `${FULL_REMOTE ? "Bash command" : "Command"} to execute` }),
      timeout: Type.Optional(Type.Number({ description: `Timeout in seconds (optional, defaults to ${DEFAULT_TIMEOUT_SECONDS}s if omitted)` })),
    }),
    execute(id, params, signal, onUpdate, _ctx) {
      return bridgeTool.execute(id, params, signal, onUpdate);
    },
    renderResult(result, options, theme, context) {
      if (!options.expanded) {
        return new Text("", 0, 0);
      }
      return originalRenderResult!(result, options, theme, context);
    },
  });

  pi.on("user_bash", () => {
    return { operations: createBridgeBashOps() };
  });

  pi.on("before_agent_start", async (event) => {
    const remoteCwd = await remotePwdCached();
    const localLine = `Current working directory: ${process.cwd().replace(/\\/g, "/")}`;
    const remoteLine = `Current working directory: ${remoteCwd}`;

    let systemPrompt = event.systemPrompt;

    const context = SPECIFIED_REMOTE ? undefined : await remoteContextFile();

    if (context) {
      const block =
        "<project_context>\n\nProject-specific instructions and guidelines:\n\n" +
        `<project_instructions path="./AGENTS.md">\n${context}\n</project_instructions>\n\n` +
        "</project_context>\n";

      systemPrompt = systemPrompt.includes(localLine)
        ? systemPrompt.replace(localLine, `${block}${localLine}`)
        : `${systemPrompt}\n\n${block}`;
    }

    systemPrompt = systemPrompt.replace(localLine, remoteLine);

    return { systemPrompt };
  });

  if (FULL_REMOTE) {
    const cwd = await remotePwdCached();

    // Resolve Tab file completion against the bridge (tool/remote sandbox)
    // filesystem instead of the pi sandbox the TUI runs in. addAutocompleteProvider
    // lives on the per-session UI context, so register it on session_start.
    let autocompleteRegistered = false;
    pi.on("session_start", (_event, ctx) => {
      if (autocompleteRegistered) return;
      ctx.ui?.addAutocompleteProvider?.(createRemoteAutocompleteProvider);
      autocompleteRegistered = true;
    });

    pi.registerTool(
      createReadToolDefinition(cwd, {
        operations: {
          readFile: remoteReadFile,
          access: (p) => remoteAccess(p, "r"),
        },
      }),
    );

    pi.registerTool(
      createWriteToolDefinition(cwd, {
        operations: {
          writeFile: remoteWriteFile,
          mkdir: remoteMkdir,
        },
      }),
    );

    pi.registerTool(
      createEditToolDefinition(cwd, {
        operations: {
          readFile: remoteReadFile,
          writeFile: remoteWriteFile,
          access: (p) => remoteAccess(p, "rw"),
        },
      }),
    );
  }
}
