import { type ChildProcess, spawn } from "node:child_process";
import * as fs from "node:fs";
import * as net from "node:net";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CONTROL_PATH = process.env.PI_SUBAGENT_CONTROL;
const FULL_REMOTE = process.env.PI_REMOTE_FILE_TOOLS === "1";
const BRAVE = process.env.PI_SUBAGENT_BRAVE === "1";

const MAX_CONCURRENT = 4;

const EXT_DIR = path.join(os.homedir(), ".pi", "agent", "extensions");

function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
	return `${Math.round(count / 1000000)}M`;
}

const SUBAGENT_SYSTEM_PROMPT = [
	"You are a subagent handling a delegated task on behalf of a main agent.",
	"You run autonomously with a fresh, isolated context and cannot ask follow-up questions.",
	"Investigate and complete the task using your tools, then report your findings concisely as your final message.",
	"Other agents may be working in the same filesystem concurrently: prefer reads, and keep any writes scoped to the task you were given to avoid colliding with disjoint work.",
].join(" ");

interface LiveSubagent {
	id: number;
	task: string;
	proc: ChildProcess;
	conn: net.Socket;
	turns: number;
	tokens: number;
	cost: number;
	lastTool?: string;
	done: boolean;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}
	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}
	return { command: "pi", args };
}

export default function (pi: ExtensionAPI) {
	if (!CONTROL_PATH) return;

	const live = new Map<number, LiveSubagent>();
	interface SubagentResult {
		exitCode: number;
		stopReason: string;
		aborted: boolean;
	}
	const finished = new Map<number, SubagentResult>();
	const waiters = new Map<number, net.Socket[]>();
	const MAX_FINISHED = 256;
	let nextId = 0;
	let server: net.Server | undefined;
	let lastCtx: any;
	let promptFile: string | undefined;

	function recordFinished(id: number, result: SubagentResult) {
		finished.set(id, result);
		while (finished.size > MAX_FINISHED) {
			const oldest = finished.keys().next().value;
			if (oldest === undefined) break;
			finished.delete(oldest);
		}
		const pending = waiters.get(id);
		if (!pending) return;
		waiters.delete(id);
		const payload = `${JSON.stringify({ type: "subagent_end", id, ...result })}\n`;
		for (const w of pending) {
			if (!w.destroyed) {
				w.write(payload);
				w.end();
			}
		}
	}

	function handleWait(conn: net.Socket, req: any) {
		const id = typeof req.id === "number" ? req.id : Number.parseInt(String(req.id), 10);
		if (!Number.isFinite(id)) {
			conn.write(`${JSON.stringify({ type: "error", message: "invalid wait id" })}\n`);
			conn.end();
			return;
		}
		const done = finished.get(id);
		if (done) {
			conn.write(`${JSON.stringify({ type: "subagent_end", id, ...done })}\n`);
			conn.end();
			return;
		}
		if (live.has(id)) {
			const arr = waiters.get(id) ?? [];
			arr.push(conn);
			waiters.set(id, arr);
			conn.on("close", () => {
				const cur = waiters.get(id);
				if (!cur) return;
				const idx = cur.indexOf(conn);
				if (idx >= 0) cur.splice(idx, 1);
				if (cur.length === 0) waiters.delete(id);
			});
			return;
		}
		if (id < nextId) {
			conn.write(
				`${JSON.stringify({ type: "subagent_end", id, exitCode: 0, stopReason: "end", aborted: false })}\n`,
			);
			conn.end();
			return;
		}
		conn.write(`${JSON.stringify({ type: "error", message: `unknown subagent ${id}` })}\n`);
		conn.end();
	}

	function ensurePromptFile(): string {
		if (promptFile && fs.existsSync(promptFile)) return promptFile;
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-subagent-"));
		promptFile = path.join(dir, "system.md");
		fs.writeFileSync(promptFile, SUBAGENT_SYSTEM_PROMPT, { encoding: "utf-8", mode: 0o600 });
		return promptFile;
	}

	function refreshStatus() {
		const ui = lastCtx?.ui;
		if (!ui?.setWidget) return;
		const running = [...live.values()].filter((s) => !s.done);
		if (running.length === 0) {
			ui.setWidget("subagents", undefined);
			return;
		}
		const parts = running.map((s) => {
			const tail = s.lastTool ? ` ${s.lastTool}` : "";
			return `#${s.id} ${formatTokens(s.tokens)}${tail}`;
		});
		ui.setWidget("subagents", [`⛭ subagents: ${running.length} · ${parts.join(" · ")}`, ""]);
	}

	function buildSubagentArgs(task: string): string[] {
		const model = lastCtx?.model ? `${lastCtx.model.provider}/${lastCtx.model.id}` : undefined;
		const thinking = lastCtx?.thinkingLevel;

		const tools = FULL_REMOTE ? ["bash", "read", "write", "edit"] : ["Command"];
		const extensions = [path.join(EXT_DIR, "pi-remote.ts")];
		if (BRAVE) {
			tools.push("web_search");
			extensions.push(path.join(EXT_DIR, "brave-search.ts"));
		}

		const args: string[] = ["--mode", "json", "-p", "--no-session", "--approve"];
		if (model) args.push("--model", model);
		if (thinking && thinking !== "off") args.push("--thinking", thinking);
		args.push("--no-tools", "--no-extensions");
		for (const e of extensions) args.push("-e", e);
		args.push("--tools", tools.join(","));
		args.push("--system-prompt", ensurePromptFile());
		args.push(`Task: ${task}`);
		return args;
	}

	function spawnSubagent(sa: Omit<LiveSubagent, "proc">): ChildProcess {
		const env = { ...process.env };
		delete env.PI_NOTIFY_SOCKET;
		delete env.PI_SUBAGENT_CONTROL;
		delete env.PI_SUBAGENT_SOCKET;

		const invocation = getPiInvocation(buildSubagentArgs(sa.task));
		return spawn(invocation.command, invocation.args, {
			cwd: process.cwd(),
			env,
			shell: false,
			stdio: ["ignore", "pipe", "pipe"],
		});
	}

	function handleEventLine(sa: LiveSubagent, line: string) {
		if (!sa.conn.destroyed) {
			sa.conn.write(`${line}\n`);
		}
		let event: any;
		try {
			event = JSON.parse(line);
		} catch {
			return;
		}
		if (event.type === "message_end" && event.message?.role === "assistant") {
			sa.turns++;
			const usage = event.message.usage;
			if (usage) {
				sa.tokens += (usage.output ?? 0) + (usage.input ?? 0);
				sa.cost += usage.cost?.total ?? 0;
			}
			for (const part of event.message.content ?? []) {
				if (part.type === "toolCall") sa.lastTool = part.name;
			}
			refreshStatus();
		} else if (event.type === "tool_result_end" && event.message) {
			refreshStatus();
		}
	}

	function handleConnection(conn: net.Socket) {
		let buf = "";
		let started = false;

		const onFirstLine = (line: string) => {
			started = true;
			let req: any;
			try {
				req = JSON.parse(line);
			} catch {
				conn.write(`${JSON.stringify({ type: "error", message: "invalid request" })}\n`);
				conn.end();
				return;
			}
			if (req.type === "wait") {
				handleWait(conn, req);
				return;
			}
			if (req.type !== "run" || typeof req.task !== "string" || !req.task.trim()) {
				conn.write(`${JSON.stringify({ type: "error", message: "invalid run request" })}\n`);
				conn.end();
				return;
			}

			const runningCount = [...live.values()].filter((s) => !s.done).length;
			if (runningCount >= MAX_CONCURRENT) {
				conn.write(`${JSON.stringify({ type: "error", message: "subagent limit reached" })}\n`);
				conn.end();
				return;
			}

			const id = nextId++;
			const logPath = `/tmp/subagent-${id}.log`;
			conn.write(`${JSON.stringify({ type: "created", id, logPath })}\n`);

			const sa: LiveSubagent = {
				id,
				task: req.task,
				conn,
				turns: 0,
				tokens: 0,
				cost: 0,
				done: false,
				proc: undefined as unknown as ChildProcess,
			};
			sa.proc = spawnSubagent(sa);
			live.set(id, sa);

			refreshStatus();

			let outBuf = "";
			sa.proc.stdout?.on("data", (chunk: Buffer) => {
				outBuf += chunk.toString();
				const lines = outBuf.split("\n");
				outBuf = lines.pop() ?? "";
				for (const l of lines) if (l.trim()) handleEventLine(sa, l);
			});
			let stderr = "";
			sa.proc.stderr?.on("data", (chunk: Buffer) => {
				stderr += chunk.toString();
			});

			const finish = (exitCode: number) => {
				if (sa.done) return;
				sa.done = true;
				if (outBuf.trim()) handleEventLine(sa, outBuf);
				const end = {
					type: "subagent_end",
					id,
					exitCode,
					stopReason: exitCode === 0 ? "end" : "error",
				};
				if (!conn.destroyed) {
					conn.write(`${JSON.stringify(end)}\n`);
					conn.end();
				}
				live.delete(id);
				recordFinished(id, { exitCode, stopReason: end.stopReason, aborted: false });
				refreshStatus();
			};

			sa.proc.on("close", (code) => finish(code ?? 0));
			sa.proc.on("error", () => {
				if (stderr.trim() && !conn.destroyed) {
					conn.write(`${JSON.stringify({ type: "error", message: stderr.trim().slice(0, 500) })}\n`);
				}
				finish(1);
			});

			conn.on("close", () => {
				if (sa.done) return;
				abortSubagent(sa);
			});
		};

		conn.on("data", (chunk: Buffer) => {
			if (started) return;
			buf += chunk.toString();
			const nl = buf.indexOf("\n");
			if (nl < 0) return;
			const line = buf.slice(0, nl);
			buf = buf.slice(nl + 1);
			onFirstLine(line);
		});

		conn.on("error", () => {});
	}

	function abortSubagent(sa: LiveSubagent) {
		sa.done = true;
		live.delete(sa.id);
		recordFinished(sa.id, { exitCode: 143, stopReason: "aborted", aborted: true });
		try {
			sa.proc.kill("SIGTERM");
		} catch {}
		setTimeout(() => {
			try {
				if (!sa.proc.killed) sa.proc.kill("SIGKILL");
			} catch {}
		}, 5000);
		refreshStatus();
	}

	function startServer() {
		if (server) return;
		try {
			fs.rmSync(CONTROL_PATH!, { force: true });
		} catch {}
		server = net.createServer(handleConnection);
		server.on("error", () => {});
		server.listen(CONTROL_PATH);
	}

	function shutdown() {
		for (const sa of [...live.values()]) abortSubagent(sa);
		try {
			server?.close();
		} catch {}
		server = undefined;
	}

	pi.on("session_start", (_event: any, ctx: any) => {
		lastCtx = ctx;
		startServer();
	});

	pi.on("agent_start", (_event: any, ctx: any) => {
		lastCtx = ctx;
	});
	pi.on("message_start", (_event: any, ctx: any) => {
		lastCtx = ctx;
	});
	pi.on("message_end", (_event: any, ctx: any) => {
		lastCtx = ctx;
	});

	try {
		pi.on("session_shutdown" as any, () => shutdown());
	} catch {}

	process.on("exit", shutdown);
	process.on("SIGTERM", () => {
		shutdown();
		process.exit(0);
	});
}
