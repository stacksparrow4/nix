import { Buffer } from "node:buffer";
import { connect } from "node:net";
import {
  type BashOperations,
  createBashTool,
  createBashToolDefinition,
  createEditToolDefinition,
  createReadToolDefinition,
  createWriteToolDefinition,
  type ExtensionAPI,
  isToolCallEventType,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";


const SOCKET_PATH = "/tmp/pi-remote/pi.sock";
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

export default async function(pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (isToolCallEventType("command", event) && event.input.timeout === undefined) {
      event.input.timeout = DEFAULT_TIMEOUT_SECONDS;
    }
    return undefined;
  });

  pi.registerTool({
    ...createBashToolDefinition("/"),
    // Avoid using the name "bash" because it could technically be a non bash command interface (eg powershell)
    name: "command",
    label: "command",
    description: `Execute a command. Returns stdout and stderr. Output may be truncated if it is too long. If no timeout is given, a default of ${DEFAULT_TIMEOUT_SECONDS} seconds is applied.`,
    promptSnippet: "Execute commands",
    parameters: Type.Object({
      command: Type.String({ description: "Command to execute" }),
      timeout: Type.Optional(Type.Number({ description: `Timeout in seconds (optional, defaults to ${DEFAULT_TIMEOUT_SECONDS}s if omitted)` })),
    }),
    async execute(id, params, signal, onUpdate, _ctx) {
      const tool = createBashTool("/", { operations: createBridgeBashOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.on("user_bash", () => {
    return { operations: createBridgeBashOps() };
  });

  if (process.env.PI_REMOTE_FILE_TOOLS === "1") {
    const cwd = await remotePwd();

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
