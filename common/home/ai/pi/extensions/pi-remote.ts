import { Buffer } from "node:buffer";
import { connect } from "node:net";
import {
  type BashOperations,
  createBashTool,
  createEditTool,
  createReadTool,
  createWriteTool,
  createBashToolDefinition,
  createEditToolDefinition,
  createReadToolDefinition,
  createWriteToolDefinition,
  type EditOperations,
  type ExtensionAPI,
  type ReadOperations,
  type WriteOperations,
} from "@mariozechner/pi-coding-agent";


const SOCKET_PATH = "/tmp/pi-remote/pi.sock";

interface ExecOptions {
  timeout?: number; // seconds
  env?: Record<string, string>;
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
        env: options.env ?? null,
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

async function execCapture(
  command: string,
  options: ExecOptions = {},
): Promise<{ stdout: Buffer; stderr: Buffer; exitCode: number | null }> {
  const result = await bridgeExec(command, options);
  if (result.error && result.exitCode === null) {
    throw new Error(result.error);
  }
  return { stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode };
}

async function execOk(command: string, options: ExecOptions = {}): Promise<Buffer> {
  const { stdout, stderr, exitCode } = await execCapture(command, options);
  if (exitCode !== 0) {
    throw new Error(
      `Command ${command} failed with exit code ${exitCode}:\n${stderr.toString("utf-8").slice(0, 2000)}`,
    );
  }
  return stdout;
}

const SHELL_SAFE = /^[A-Za-z0-9_@%+=:,./-]+$/;
function shq(value: string): string {
  if (value.length === 0) return "''";
  if (SHELL_SAFE.test(value)) return value;
  return `'${value.replace(/'/g, "'\\''")}'`;
}

function createBridgeReadOps(): ReadOperations {
  return {
    readFile: async (p) => execOk(`cat -- ${shq(p)}`),
    access: async (p) => {
      await execOk(`test -r ${shq(p)}`);
    },
    detectImageMimeType: async (p) => {
      try {
        const out = await execOk(`file --mime-type -b -- ${shq(p)}`);
        const mime = out.toString("utf-8").trim();
        return ["image/jpeg", "image/png", "image/gif", "image/webp"].includes(mime) ? mime : null;
      } catch {
        return null;
      }
    },
  };
}

function createBridgeWriteOps(): WriteOperations {
  return {
    writeFile: async (p, content) => {
      const b64 = Buffer.from(content, "utf-8").toString("base64");
      await execOk(`printf %s ${shq(b64)} | base64 -d > ${shq(p)}`);
    },
    mkdir: async (dir) => {
      await execOk(`mkdir -p -- ${shq(dir)}`);
    },
  };
}

function createBridgeEditOps(): EditOperations {
  const r = createBridgeReadOps();
  const w = createBridgeWriteOps();
  return {
    readFile: r.readFile,
    access: async (p) => {
      await execOk(`test -r ${shq(p)} && test -w ${shq(p)}`);
    },
    writeFile: w.writeFile,
  };
}

function createBridgeBashOps(): BashOperations {
  return {
    exec: async (command, _cwd, { onData, signal, timeout, env }) => {
      const result = await bridgeExec(command, {
        timeout,
        env: env
          ? (Object.fromEntries(
            Object.entries(env).filter(([, v]) => typeof v === "string"),
          ) as Record<string, string>)
          : undefined,
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

export default function(pi: ExtensionAPI) {
  pi.registerTool({
    ...createReadToolDefinition("/"),
    async execute(id, params, signal, onUpdate, _ctx) {
      const tool = createReadTool("/", { operations: createBridgeReadOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...createWriteToolDefinition("/"),
    async execute(id, params, signal, onUpdate, _ctx) {
      const tool = createWriteTool("/", { operations: createBridgeWriteOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...createEditToolDefinition("/"),
    async execute(id, params, signal, onUpdate, _ctx) {
      const tool = createEditTool("/", { operations: createBridgeEditOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...createBashToolDefinition("/"),
    async execute(id, params, signal, onUpdate, _ctx) {
      const tool = createBashTool("/", { operations: createBridgeBashOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.on("user_bash", () => {
    return { operations: createBridgeBashOps() };
  });
}
