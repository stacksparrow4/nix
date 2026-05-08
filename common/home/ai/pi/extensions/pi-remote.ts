import { Buffer } from "node:buffer";
import { connect } from "node:net";
import {
	type BashOperations,
	createBashTool,
	createEditTool,
	createFindTool,
	createLsTool,
	createReadTool,
	createWriteTool,
	type EditOperations,
	type ExtensionAPI,
	type FindOperations,
	type LsOperations,
	type ReadOperations,
	type WriteOperations,
} from "@earendil-works/pi-coding-agent";

interface ExecOptions {
	cwd?: string;
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

function bridgeExec(socketPath: string, command: string, options: ExecOptions = {}): Promise<ExecResult> {
	return new Promise((resolve, reject) => {
		const sock = connect(socketPath);
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
				cwd: options.cwd ?? null,
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
			settle(new Error(`bridge socket error (${socketPath}): ${err.message}`));
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
	socketPath: string,
	command: string,
	options: ExecOptions = {},
): Promise<{ stdout: Buffer; stderr: Buffer; exitCode: number | null }> {
	const result = await bridgeExec(socketPath, command, options);
	if (result.error && result.exitCode === null) {
		throw new Error(result.error);
	}
	return { stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode };
}

async function execOk(socketPath: string, command: string, options: ExecOptions = {}): Promise<Buffer> {
	const { stdout, stderr, exitCode } = await execCapture(socketPath, command, options);
	if (exitCode !== 0) {
		throw new Error(
			`bridge command failed (exit ${exitCode}): ${command}\n${stderr.toString("utf-8").slice(0, 2000)}`,
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

function createBridgeReadOps(socketPath: string): ReadOperations {
	return {
		readFile: async (p) => execOk(socketPath, `cat -- ${shq(p)}`),
		access: async (p) => {
			await execOk(socketPath, `test -r ${shq(p)}`);
		},
		detectImageMimeType: async (p) => {
			try {
				const out = await execOk(socketPath, `file --mime-type -b -- ${shq(p)}`);
				const mime = out.toString("utf-8").trim();
				return ["image/jpeg", "image/png", "image/gif", "image/webp"].includes(mime) ? mime : null;
			} catch {
				return null;
			}
		},
	};
}

function createBridgeWriteOps(socketPath: string): WriteOperations {
	return {
		writeFile: async (p, content) => {
			const b64 = Buffer.from(content, "utf-8").toString("base64");
			await execOk(socketPath, `printf %s ${shq(b64)} | base64 -d > ${shq(p)}`);
		},
		mkdir: async (dir) => {
			await execOk(socketPath, `mkdir -p -- ${shq(dir)}`);
		},
	};
}

function createBridgeEditOps(socketPath: string): EditOperations {
	const r = createBridgeReadOps(socketPath);
	const w = createBridgeWriteOps(socketPath);
	return {
		readFile: r.readFile,
		access: async (p) => {
			await execOk(socketPath, `test -r ${shq(p)} && test -w ${shq(p)}`);
		},
		writeFile: w.writeFile,
	};
}

function createBridgeBashOps(socketPath: string): BashOperations {
	return {
		exec: async (command, cwd, { onData, signal, timeout, env }) => {
			const result = await bridgeExec(socketPath, command, {
				cwd,
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

function createBridgeLsOps(socketPath: string): LsOperations {
	return {
		exists: async (p) => {
			const { exitCode } = await execCapture(socketPath, `test -e ${shq(p)}`);
			return exitCode === 0;
		},
		stat: async (p) => {
			const { exitCode } = await execCapture(socketPath, `test -d ${shq(p)}`);
			const isDir = exitCode === 0;
			return { isDirectory: () => isDir };
		},
		readdir: async (p) => {
			// -A skips . and ..; -1 forces one entry per line; -- terminates options.
			const out = await execOk(socketPath, `ls -A -1 -- ${shq(p)}`);
			return out
				.toString("utf-8")
				.split("\n")
				.map((l) => l.trim())
				.filter((l) => l.length > 0);
		},
	};
}

function createBridgeFindOps(socketPath: string): FindOperations {
	return {
		exists: async (p) => {
			const { exitCode } = await execCapture(socketPath, `test -e ${shq(p)}`);
			return exitCode === 0;
		},
		glob: async (pattern, cwd, { ignore, limit }) => {
			// Prefer fd if present, fall back to find.
			const ignoreArgsFd = ignore.flatMap((g) => ["--exclude", shq(g)]).join(" ");
			const ignoreArgsFind = ignore
				.map((g) => `! -path ${shq(`*/${g}/*`)} ! -name ${shq(g)}`)
				.join(" ");
			const lim = Math.max(1, Math.floor(limit));
			const cmd =
				`if command -v fd >/dev/null 2>&1; then ` +
				`  fd --hidden --no-ignore-vcs --max-results ${lim} ${ignoreArgsFd} -- ${shq(pattern)} ${shq(cwd)};` +
				`else ` +
				`  find ${shq(cwd)} ${ignoreArgsFind} -name ${shq(pattern)} -print 2>/dev/null | head -n ${lim};` +
				`fi`;
			const out = await execOk(socketPath, cmd);
			return out
				.toString("utf-8")
				.split("\n")
				.map((l) => l.trim())
				.filter((l) => l.length > 0);
		},
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerFlag("bridge-socket", {
		description: "Path to the host bridge unix socket (overrides PI_BRIDGE_SOCKET)",
		type: "string",
	});

	const localCwd = process.cwd();

	// Define originals so we can fall back if the bridge is not configured.
	const localRead = createReadTool(localCwd);
	const localWrite = createWriteTool(localCwd);
	const localEdit = createEditTool(localCwd);
	const localBash = createBashTool(localCwd);
	const localLs = createLsTool(localCwd);
	const localFind = createFindTool(localCwd);

	let socketPath: string | undefined;
	const getSocket = () => socketPath;

	pi.registerTool({
		...localRead,
		async execute(id, params, signal, onUpdate, _ctx) {
			const sp = getSocket();
			if (sp) {
				const tool = createReadTool(localCwd, { operations: createBridgeReadOps(sp) });
				return tool.execute(id, params, signal, onUpdate);
			}
			return localRead.execute(id, params, signal, onUpdate);
		},
	});

	pi.registerTool({
		...localWrite,
		async execute(id, params, signal, onUpdate, _ctx) {
			const sp = getSocket();
			if (sp) {
				const tool = createWriteTool(localCwd, { operations: createBridgeWriteOps(sp) });
				return tool.execute(id, params, signal, onUpdate);
			}
			return localWrite.execute(id, params, signal, onUpdate);
		},
	});

	pi.registerTool({
		...localEdit,
		async execute(id, params, signal, onUpdate, _ctx) {
			const sp = getSocket();
			if (sp) {
				const tool = createEditTool(localCwd, { operations: createBridgeEditOps(sp) });
				return tool.execute(id, params, signal, onUpdate);
			}
			return localEdit.execute(id, params, signal, onUpdate);
		},
	});

	pi.registerTool({
		...localBash,
		async execute(id, params, signal, onUpdate, _ctx) {
			const sp = getSocket();
			if (sp) {
				const tool = createBashTool(localCwd, { operations: createBridgeBashOps(sp) });
				return tool.execute(id, params, signal, onUpdate);
			}
			return localBash.execute(id, params, signal, onUpdate);
		},
	});

	pi.registerTool({
		...localLs,
		async execute(id, params, signal, onUpdate, _ctx) {
			const sp = getSocket();
			if (sp) {
				const tool = createLsTool(localCwd, { operations: createBridgeLsOps(sp) });
				return tool.execute(id, params, signal, onUpdate);
			}
			return localLs.execute(id, params, signal, onUpdate);
		},
	});

	pi.registerTool({
		...localFind,
		async execute(id, params, signal, onUpdate, _ctx) {
			const sp = getSocket();
			if (sp) {
				const tool = createFindTool(localCwd, { operations: createBridgeFindOps(sp) });
				return tool.execute(id, params, signal, onUpdate);
			}
			return localFind.execute(id, params, signal, onUpdate);
		},
	});

	// Forward user-typed `!` / `!!` shell commands through the bridge as well.
	pi.on("user_bash", () => {
		const sp = getSocket();
		if (!sp) return;
		return { operations: createBridgeBashOps(sp) };
	});

	pi.on("session_start", async (_event, ctx) => {
		const fromFlag = pi.getFlag("bridge-socket") as string | undefined;
		const fromEnv = process.env.PI_BRIDGE_SOCKET;
		socketPath = fromFlag || fromEnv || undefined;

		if (!socketPath) {
			ctx.ui.notify(
				"pi-extension: PI_BRIDGE_SOCKET not set and --bridge-socket not provided; tools run locally inside the sandbox.",
				"warning",
			);
			return;
		}

		// Probe the bridge with a no-op so we surface configuration problems early.
		try {
			await execOk(socketPath, "true", { timeout: 5 });
			ctx.ui.setStatus("bridge", ctx.ui.theme.fg("accent", `bridge: ${socketPath}`));
			ctx.ui.notify(`Host bridge connected: ${socketPath}`, "info");
		} catch (err) {
			const msg = err instanceof Error ? err.message : String(err);
			ctx.ui.notify(`Host bridge unreachable at ${socketPath}: ${msg}`, "error");
			socketPath = undefined;
		}
	});

	// Make it clear in the system prompt that tools target the host.
	pi.on("before_agent_start", (event) => {
		if (!socketPath) return;
		const note = `\n\nNote: read, write, edit, bash, ls, and find run on the host through a bridge socket (${socketPath}). Paths refer to the host filesystem, not this sandbox.`;
		return { systemPrompt: event.systemPrompt + note };
	});
}
