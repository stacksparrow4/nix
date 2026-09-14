# Subagents Design

Design document for adding subagent support to the custom Pi setup. Written to be
implemented by another agent. Read this together with the existing code it references.

## 1. Goal

Let the main Pi agent delegate a task to a **subagent**: a fresh, isolated-context
agent that inherits the current model/thinking level, runs autonomously, and reports
back through a log file. Subagents are launched by the model itself, on demand, via a
`subagent` CLI it calls through its normal `bash`/`Command` tool — **not** via a
registered Pi tool.

### Why a CLI instead of a Pi tool

- **No prompt-cache invalidation.** Registering a tool at runtime mutates the tool set
  and invalidates the cached prompt prefix (see the note in
  `modules/pkgs/pi/extensions/goal.ts` about `complete_goal`). A CLI invoked through the
  already-present `bash` tool adds **zero** new tools; the cached prefix is untouched.
- **Opt-in.** The capability is advertised with a few static lines in the (cached) system
  prompt, rather than an always-present tool nudging the model to use it.
- **Unix-native ergonomics.** `run` / `wait` plus native `ps` / `kill` and the agent's
  existing `read` tool cover the whole lifecycle. No bespoke `logs` command.

### Key decisions (already settled)

1. The subagent **agent loop runs on the privileged (brain) side**, not in the tool
   sandbox. This enables TUI rendering and keeps the real `pi` out of the tool sandbox
   (preserving the current "no agent runtime in the tool sandbox" invariant). It also
   means the subagent has **native provider access** — no credential-injecting proxy is
   needed.
2. The subagent's **tools reuse the existing brain→tool bridge**
   (`/tmp/pi-remote/pi.sock`), so its `read`/`write`/`edit`/`bash` act on the same real
   files as the main agent. The bridge is already concurrency-safe (thread-per-connection,
   `accept_loop` in `modules/pkgs/pi/src/remote.rs`).
3. **One socket connection per subagent** does triple duty: the creation request, the
   log-event stream, and the liveness/abort handle.
4. **Logs are a file in the tool sandbox `/tmp`.** `subagent run` returns
   `"Agent started. Log at /tmp/subagent-N.log"`. The agent reads it with its normal
   `read` tool (progress mid-run, final result after `wait`). No cleanup command — the
   tool sandbox `/tmp` is ephemeral.
5. **Model/thinking is inherited live** from the brain's `ctx.model` / `ctx.thinkingLevel`
   at spawn time.

## 2. Background: current architecture

The `pi` command is a Rust wrapper (`modules/pkgs/pi/src/main.rs`) that runs the real
`pi-coding-agent` inside a split sandbox:

- **Brain sandbox** (`box` invocation at the end of `main()`): runs the real `pi`
  (`$SPRRW_PI`) with `--no-tools --no-extensions`, the LLM lives here, credentials
  (`~/.pi/agent/auth.json`) are mounted here. No access to the real working files.
- **Tool sandbox** (`start_tool_sandbox`, a `box --docker` running
  `$SPRRW_PI_WRAPPER_LINUX --internal-serve`): where `bash`/`read`/`write`/`edit` actually
  execute. A host tempdir is mounted `rw` into it at `BRIDGE_DIR = /tmp/pi-remote`, and it
  binds `/tmp/pi-remote/pi.sock` (see `serve_local` in `remote.rs`).
- **Bridge:** the brain's `pi-remote.ts` extension connects to `/tmp/pi-remote/pi.sock`
  and proxies tool calls into the tool sandbox. The same host tempdir is mounted `ro` into
  the brain. This proves **cross-sandbox unix sockets over a shared host bind mount work**
  in this setup (one side binds, the other connects).

Relevant wiring already present, to mirror:

- `start_notify_server` (`notify.rs`): host-side `UnixListener` in a tempdir, mounted into
  the sandbox, env `PI_NOTIFY_SOCKET` points the sandbox at it. Extension `notify.ts`
  connects out to it. **This is the template for a host-served socket.**
- `box` PATH extension: `container.rs` reads `SPRRW_PATH` / `SPRRW_ADDITIONAL_PATH` from
  its environment and prepends them to the sandbox `PATH`. **This is how to put the
  `subagent` binary on PATH inside the tool sandbox.**
- Extension lists in `main.rs`: `DEFAULT_EXTENSIONS`, `REQUIRED_EXTENSIONS`, `DEFAULT_TOOLS`.
- Extension/prompt volumes: `$SPRRW_EXTENSIONS` → `~/.pi/agent/extensions`,
  `$SPRRW_PROMPTS` → `~/.pi/agent/prompts` (see the final `box` args in `main.rs` and the
  `piWrapper` in `modules/pkgs/pi/default.nix`).

**Scope:** v1 targets `Target::Sandbox` only (the local `box --docker` tool sandbox).
`--remote` / `--universal-remote` / `--vm` targets are out of scope (see §9).

## 3. Architecture

```
 tool sandbox (box --docker)                 brain sandbox (box)
 ───────────────────────────                 ─────────────────────────────
 main agent's bash ──► subagent CLI          real pi (brain) + extensions
                          │                     │
                          │ connect             │  subagent-control.ts (extension)
                          ▼                     │   - binds control socket
        control.sock  ◄───┼─────────────────────┤   - on "run": spawns headless
        (shared host      │  run{task}          │     subagent pi subprocess
         bind mount,      │──────────────────►  │   - renders subagent in TUI
         rw both sides)   │  {id, logPath}      │   - streams jsonl events back
                          │ ◄──────────────────  │
                          │  jsonl event lines   │        subagent pi subprocess
                          │ ◄─────────────────── │        (pi --mode json -p)
       fork: parent prints path & exits         │          │ tools via pi-remote.ts
       child = writer = ps/kill handle          │          ▼
                          │                      └──► /tmp/pi-remote/pi.sock (bridge)
       writer ──append──► /tmp/subagent-N.log             (same tool sandbox fs)
```

- The **subagent-control.ts** extension (brain) owns the whole subagent lifecycle:
  binding the control socket, spawning subagent `pi` subprocesses, rendering them in the
  TUI, and forwarding their event stream back over the control connection.
- The subagent `pi` subprocess is a child of the brain process: it inherits the brain's
  credentials and network, and loads only `pi-remote.ts` so its tools run in the shared
  tool sandbox.
- The **subagent CLI** (tool sandbox) is a thin control client: it opens one connection,
  sends `run`, gets back `{id, logPath}`, daemonizes, and the surviving child streams
  events to `/tmp/subagent-N.log`. That child is the `ps`/`kill` handle.

## 4. Components

### 4.1 Wrapper changes — `modules/pkgs/pi/src/main.rs`

1. **Create the control-socket dir.** Before launching the tool sandbox and brain, create
   a host tempdir (like `start_notify_server` / `start_tool_sandbox` do). Call it
   `control_dir`.
2. **Mount it into both sandboxes, `rw`, at the same path** (e.g. `/tmp/pi-subagent`):
   - Tool sandbox: add to the `start_tool_sandbox` `box` args.
   - Brain: add to the final `box` args.
   The socket file is `/tmp/pi-subagent/control.sock`.
3. **Env vars:**
   - Brain: `PI_SUBAGENT_CONTROL=/tmp/pi-subagent/control.sock` (the extension **binds**
     this).
   - Tool sandbox: `PI_SUBAGENT_SOCKET=/tmp/pi-subagent/control.sock` (the CLI **connects**
     here).
4. **Put the CLI on PATH in the tool sandbox.** Set `SPRRW_PATH` (or
   `SPRRW_ADDITIONAL_PATH`) in the environment of the `start_tool_sandbox` `box` command to
   include the `subagent` binary's `bin` dir. The binary is a Linux build (tool sandbox is
   Linux); expose its store path from Nix (see §4.6). Prefer a dedicated env, e.g.
   `SPRRW_SUBAGENT_BIN`, that `main.rs` folds into `SPRRW_PATH` for the tool sandbox.
5. **Register the control extension.** Add `"subagent-control.ts"` to `DEFAULT_EXTENSIONS`
   (it is brain-only; it registers no model-visible tool, so no cache impact). Do **not**
   add anything to `DEFAULT_TOOLS`.
6. **Gate on target.** Only wire steps 1–5 when `target` is `Target::Sandbox`. For other
   targets, do not set the env vars (the CLI and extension both no-op when their env var is
   absent — see §4.2/§4.3).
7. **Pass the subagent spawn essentials to the extension.** The extension needs to
   re-invoke the real `pi`. It already runs as a child of `$SPRRW_PI`; `process.execPath`
   inside it resolves to the real `pi` binary (same logic as `getPiInvocation` in the
   upstream subagent example). No new env needed for this, but confirm during
   implementation.

### 4.2 The `subagent` CLI (new Rust crate)

New crate, e.g. `modules/pkgs/subagent/`, producing a Linux binary named `subagent`.
Two subcommands.

#### `subagent run <task...>`

1. If `PI_SUBAGENT_SOCKET` is unset, print an error (`subagents unavailable in this
   context`) and exit non-zero.
2. Connect to `$PI_SUBAGENT_SOCKET`.
3. Send one JSON line: `{"type":"run","task":"<task>","cwd":"<pwd>"}` (see §4.4 for schema;
   `cwd` optional).
4. Read the reply line `{"type":"created","id":N,"logPath":"/tmp/subagent-N.log"}`.
5. Print `Agent started. Log at /tmp/subagent-N.log` to stdout.
6. **Daemonize** (double-fork / `setsid`): the parent exits `0` (so the calling `bash`
   returns immediately, well within its timeout); the child keeps the socket fd.
7. Child (the **writer**):
   - Sets its process title / `argv[0]` to something greppable, e.g.
     `subagent[N]: <task snippet>`, so `ps` is meaningful.
   - Writes a pidfile `/tmp/subagent-N.pid` (for `wait`; see below).
   - Reads event lines from the socket and appends each to `/tmp/subagent-N.log`.
   - On a terminal event (`{"type":"subagent_end",...}`) or socket EOF: flush, remove the
     pidfile, exit.
   - On `SIGTERM` (from `kill <pid>`): close the socket and exit. Closing the socket makes
     the brain abort the subagent — **the exact half-close idiom the bridge already uses**
     (`onAbort` → `sock.end()` in `pi-remote.ts`; the server kills the child). A signal
     handler is only needed to write a final `[aborted]` marker; default termination
     already closes the fd.

#### `subagent wait <N>`

Block until subagent `N` finishes, without burning tokens on polling:

- Primary: read `/tmp/subagent-N.pid`; if it exists, `tail --pid=<pid> -f /dev/null`
  (or equivalent `pidfd`/poll loop). When the writer exits, `wait` returns. If the pidfile
  is absent, the subagent already finished — return immediately.
- The agent then does a final `read` of `/tmp/subagent-N.log`.

`ps`, `kill <pid>`, and `read <logPath>` are **native** — no subcommands needed for them.

### 4.3 The brain-side extension — `modules/pkgs/pi/extensions/subagent-control.ts`

Runs in the brain. No `registerTool` (that would defeat the cache-invalidation goal).

Responsibilities:

1. **On load / `session_start`:** if `process.env.PI_SUBAGENT_CONTROL` is unset, no-op.
   Otherwise bind a `net.createServer()` on that path (extensions already use `node:net` —
   see `notify.ts`, `pi-remote.ts`). Register a `session_shutdown` handler to close the
   server and kill any live subagents.
2. **Assign ids** from a monotonic counter (`0, 1, 2, ...`). Track live subagents in a map
   `id → { proc, connection, status }`.
3. **On a `run` request** (one line per connection):
   - Enforce a **max concurrent subagents** cap (e.g. 4). If exceeded, reply
     `{"type":"error","message":"subagent limit reached"}` and close.
   - Allocate `id`, compute `logPath = /tmp/subagent-<id>.log`, reply
     `{"type":"created","id":<id>,"logPath":"<logPath>"}`.
   - Spawn the subagent `pi` subprocess (see §4.5).
   - For each jsonl line the subprocess emits on stdout: (a) render it in the TUI, and
     (b) forward it verbatim over this connection to the writer.
   - On subprocess exit: send `{"type":"subagent_end","id":<id>,"exitCode":<c>,
     "stopReason":"<...>"}`, then close the connection. Remove from the live map (keep a
     small completed-set if you implement socket-based `wait`).
   - If the connection drops (writer killed / sandbox torn down): **abort** the subprocess
     (`proc.kill("SIGTERM")`, then `SIGKILL` after a grace period — mirror the upstream
     subagent example's abort handling).
4. **TUI rendering:** reuse the upstream subagent example's rendering
   (`packages/coding-agent/examples/extensions/subagent/index.ts`): parse `message_end`
   and `tool_result_end` events, show tool calls, usage stats (turns / tokens / cost /
   ctx), and the final markdown output. Render concurrently-running subagents with live
   status. Since there is no tool call to attach to, present them via a custom footer
   line and/or `ctx.ui` notifications/status; decide the exact surface during
   implementation (a persistent panel listing active subagents is ideal).

### 4.4 Control-socket protocol (JSONL, one object per line)

Client → server:

```json
{"type":"run","task":"<string>","cwd":"<string, optional>"}
```

Server → client (in order, on the same connection):

```json
{"type":"created","id":0,"logPath":"/tmp/subagent-0.log"}
```

then zero or more raw subagent event lines (verbatim `pi --mode json` output), e.g.
`{"type":"message_end","message":{...}}`, then finally:

```json
{"type":"subagent_end","id":0,"exitCode":0,"stopReason":"end"}
```

Error before creation:

```json
{"type":"error","message":"<reason>"}
```

Abort: client closes the socket (half-close). Server treats EOF as "abort subagent".

### 4.5 Subagent `pi` subprocess invocation (spawned by the extension)

Build argv like the upstream example's `runSingleAgent`, but with **fixed** generic
config (no agent definitions):

```
pi --mode json -p --no-session --approve
   --model <ctx.model as "provider/id">          # inherited, live
   --thinking <ctx.thinkingLevel>                # inherited, live
   --no-tools --no-extensions
   -e ~/.pi/agent/extensions/pi-remote.ts        # tools via the shared bridge
   --tools <TOOLS>                               # see below
   --append-system-prompt <generic-prompt-file>  # see below
   "Task: <task>"
```

- **`<TOOLS>`** must match what `pi-remote.ts` registers, which depends on
  `PI_REMOTE_FILE_TOOLS`: `bash,read,write,edit,web_search` when it is `1` (the
  `Target::Sandbox` case), else `Command,web_search`. Read the env to decide.
- **`--approve`** is required: the child is non-interactive (`-p --mode json`), like the
  brain itself (`main.rs` passes `--approve`).
- **`--no-extensions -e pi-remote.ts`** means the child gets **only** the bridge — it does
  not load `subagent-control.ts`, `footer.ts`, `notify.ts`, etc. (no recursion via the
  extension, no duplicate footers/notifications).
- **Generic system prompt:** either a constant baked into the extension (e.g. *"You are a
  subagent handling a delegated task. Investigate and complete it, then report your
  findings concisely."*) written to a temp file, or the parent's captured
  `event.systemPrompt` (from a `before_agent_start` hook) for identical environment
  guidelines. Start with the constant; capturing the parent prompt is an easy upgrade.
- **Environment sanitization** for the child: inherit the brain's env, but **unset
  `PI_NOTIFY_SOCKET`** (subagents should not fire desktop notifications). Keep
  `PI_REMOTE_FILE_TOOLS`, `PI_READ_AGENTS_MD`, `PI_CACHE_RETENTION`.
- **Model note:** read `ctx.model` (`${provider}/${id}`) and `ctx.thinkingLevel` at spawn
  time so the subagent tracks the brain's current selection.

### 4.6 Nix packaging — `modules/pkgs/subagent/` + `modules/pkgs/pi/default.nix`

- New crate `modules/pkgs/subagent/` built like the other Rust packages (`crate2nix`,
  mirror `modules/pkgs/pi/default.nix` / `oob`). Produce a Linux build (`pkgsLinux`) since
  it runs in the tool sandbox.
- In `piWrapper` (`modules/pkgs/pi/default.nix`), export the new env so `main.rs` sees it:
  - `SPRRW_SUBAGENT_BIN=${subagentLinux}/bin` (folded into the tool sandbox `SPRRW_PATH`).
  - Add `subagent-control.ts` to the `extensions/` dir (it already ships via
    `$SPRRW_EXTENSIONS`).
- The extension imports from `@earendil-works/pi-coding-agent` / `@earendil-works/pi-tui`
  like the existing extensions; if it needs the upstream subagent rendering helpers, vendor
  the relevant parts into the extension file (the existing extensions are self-contained
  single files).

## 5. Lifecycle & edge cases

- **`run` returns fast:** daemonize before streaming; never block the calling `bash`.
- **Abort via `kill`:** `kill <writer-pid>` → socket close → brain aborts subprocess. Falls
  out of the single-connection design; no separate abort command.
- **Sandbox teardown:** if the whole tool sandbox dies, every writer's socket closes → the
  brain auto-aborts all subagents. The connection is the lease; no orphans, no cleanup
  command.
- **`wait` after completion:** pidfile removed on writer exit → `wait` returns immediately.
- **Log = jsonl:** raw `pi --mode json` event stream. The final answer is the last
  `assistant` `message_end` text. The agent can `read`/`grep`/`jq` it. (Optional future:
  a distilled human-readable log or a `subagent result N` extractor — not in v1.)
- **Reading a live log:** append-only jsonl; the agent may `read` it mid-run for progress
  and again after `wait` for the result.

## 6. Recursion & concurrency control

A subagent's `bash` runs in the **same** tool sandbox and can therefore see the `subagent`
CLI and the control socket, so it *could* call `subagent run` itself. Env-based depth
guards do **not** propagate (bridge-run commands use the tool sandbox's fixed env, not the
subagent process's env). Therefore:

- The **brain enforces a hard cap** on concurrent subagents (e.g. 4) and rejects `run`
  beyond it. This bounds runaway recursion regardless of who calls `run`.
- Optionally also cap total spawns per session and/or add a simple rate limit.
- Multiple subagents + the main agent share the tool sandbox filesystem via the same
  bridge. Concurrent reads are fine; concurrent writers to the same file can collide — this
  is inherent and acceptable, but worth a line in the subagent system prompt encouraging
  disjoint work.

## 7. Security considerations

- **No new credential exposure.** The loop is privileged-side; the tool sandbox never sees
  provider credentials. (The earlier credential-injecting proxy idea is unnecessary and is
  **not** part of this design.)
- **Control socket** is on a host bind mount shared only between the two sandboxes; it
  carries only `run` requests and event streams. It cannot be used to run arbitrary host
  commands.
- **Subagent capabilities** equal the main agent's (same bridge, same tools). No
  escalation.

## 8. Implementation checklist

- [ ] `modules/pkgs/subagent/` crate: `run` + `wait`, daemonize, writer, pidfile, argv
      title, SIGTERM→close. Linux build.
- [ ] `modules/pkgs/pi/extensions/subagent-control.ts`: bind control socket, spawn
      subagent `pi`, TUI render, stream forwarding, concurrency cap, abort-on-EOF,
      `session_shutdown` cleanup.
- [ ] `modules/pkgs/pi/src/main.rs`: create `control_dir`; mount `rw` into both sandboxes
      at `/tmp/pi-subagent`; set `PI_SUBAGENT_CONTROL` (brain) and `PI_SUBAGENT_SOCKET`
      (tool sandbox); fold `SPRRW_SUBAGENT_BIN` into the tool sandbox `SPRRW_PATH`; add
      `subagent-control.ts` to `DEFAULT_EXTENSIONS`; gate all of this on `Target::Sandbox`.
- [ ] `modules/pkgs/pi/default.nix`: build `subagentLinux`, export `SPRRW_SUBAGENT_BIN`,
      ensure the new extension ships in `$SPRRW_EXTENSIONS`.
- [ ] System-prompt advertisement: add a short static note to the brain's generated system
      prompt (`main.rs`) describing the `subagent run`/`wait` CLI, so the model knows it
      exists. Keep it in the cached base prompt.
- [ ] Manual test: `subagent run "..."` returns a path immediately; `read` shows streaming
      jsonl; the subagent appears in the TUI; `ps`/`kill` work; `wait` blocks then returns;
      concurrency cap rejects the 5th; killing the sandbox aborts subagents.

## 9. Out of scope / future

- `--remote`, `--universal-remote`, `--vm` targets (no local tool sandbox to host the CLI
  and control mount). The CLI and extension no-op without their env vars, so these targets
  simply have no subagents in v1.
- Parallel/chain orchestration helpers (the model can already background multiple
  `subagent run &` invocations and `wait` on each).
- Distilled/human-readable logs or a `subagent result N` extractor.
- Capturing the parent's system prompt instead of a constant generic prompt.
- Live model-switch propagation is already handled (read at spawn); no per-subagent
  re-selection.
