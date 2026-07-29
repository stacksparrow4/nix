//! Command bridge server.
//!
//! Serves the protocol spoken by `common/home/ai/pi/extensions/pi-remote.ts`, so a
//! caller outside a sandbox can run commands inside it.
//!
//! Wire format is newline-delimited JSON over a unix socket, one command per
//! connection:
//!
//! ```text
//! -> {"command": "...", "timeout": <seconds>|null}
//! <- {"type": "stdout"|"stderr", "data": "<base64>"}   (streamed, repeated)
//! <- {"type": "exit", "code": <int>}
//!  | {"type": "error", "message": "..."}
//! ```
//!
//! Details the client depends on, do not change casually:
//!
//! * Output must be streamed as it arrives; the client renders it live.
//! * The connection must be closed after the final message. The client only
//!   settles its promise on socket close, so failing to close hangs it forever.
//! * A timeout must be reported as an `error` whose message *starts with*
//!   "timeout" -- the client detects timeouts with `/^timeout/i` rather than by
//!   looking at a field.
//! * The client cancels by half-closing its end of the socket, and expects that
//!   to kill the running command.
//! * A null timeout means "use the server default".

use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    net::Shutdown,
    os::unix::{
        fs::{FileTypeExt, PermissionsExt},
        net::{UnixListener, UnixStream},
        process::CommandExt,
    },
    path::Path,
    process::{Child, Command, Stdio},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    thread,
    time::{Duration, Instant},
};

use base64::prelude::*;
use serde::Deserialize;
use serde_json::json;
use wait_timeout::ChildExt;

/// Socket filename inside the bridge directory. Must match SOCKET_PATH in
/// pi-remote.ts, which hardcodes /tmp/pi-remote/pi.sock.
pub const SOCKET_NAME: &str = "pi.sock";

/// Applied when the client sends `"timeout": null`.
pub const DEFAULT_COMMAND_TIMEOUT: u64 = 60;

/// Longest path a unix socket can be bound to, excluding the NUL terminator.
pub const MAX_SOCKET_PATH: usize = 107;

/// Placeholder substituted by [`Template`].
pub const CMD_PLACEHOLDER: &str = "<CMD>";

/// coreutils `timeout` reports this when it had to kill the command.
const TIMEOUT_EXIT_CODE: i32 = 124;

/// Once the command has exited, stop draining after this long with no output.
const DRAIN_IDLE_MS: u64 = 250;

/// Upper bound on draining, in case an orphan keeps producing output forever.
const DRAIN_CAP_SECS: u64 = 2;

/// The two pipes have different concrete types, so they need a common carrier to
/// go through one loop.
enum Pipe {
    Out(std::process::ChildStdout),
    Err(std::process::ChildStderr),
}

enum PumpEvent {
    Data,
    Done,
}

#[derive(Deserialize)]
struct Request {
    command: String,
    #[serde(default)]
    timeout: Option<f64>,
}

/// Turns a command from the wire into a running process.
pub trait Executor: Send + Sync + 'static {
    fn spawn(&self, command: &str, timeout: u64) -> std::io::Result<Child>;

    /// How long to wait locally for the child. Executors that enforce the timeout
    /// on the far side need slack so that their own reporting wins.
    fn local_timeout(&self, timeout: u64) -> u64 {
        timeout
    }
}

fn spawn_script(script: &str) -> std::io::Result<Child> {
    Command::new("bash")
        .arg("-c")
        .arg(script)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        // Own process group, so a timeout or a cancel takes down the whole
        // command tree rather than just the top-level shell.
        .process_group(0)
        .spawn()
}

/// Runs commands in this process's own context. Used by the in-sandbox agent,
/// where "this context" is the inside of a bwrap sandbox.
pub struct Local;

impl Executor for Local {
    fn spawn(&self, command: &str, _timeout: u64) -> std::io::Result<Child> {
        spawn_script(command)
    }
}

/// Runs commands on this host by substituting them into a template, for
/// caller-supplied remotes.
pub struct Template(pub String);

impl Template {
    pub fn is_valid(template: &str) -> bool {
        template.contains(CMD_PLACEHOLDER)
    }
}

impl Executor for Template {
    fn spawn(&self, command: &str, _timeout: u64) -> std::io::Result<Child> {
        let quoted = shlex::try_quote(command).expect("Failed to quote command");
        spawn_script(&self.0.replace(CMD_PLACEHOLDER, &quoted))
    }
}

/// Runs commands inside a VM over an already-multiplexed ssh connection.
pub struct Ssh {
    /// Full ssh invocation including all -o options, but no command.
    pub base: Vec<String>,
    /// Directory to run commands in, inside the VM.
    pub cwd: String,
    /// Seconds between SIGTERM and SIGKILL on the far side.
    pub grace: u64,
}

impl Executor for Ssh {
    fn spawn(&self, command: &str, timeout: u64) -> std::io::Result<Child> {
        // The command travels base64-encoded and is decoded straight into
        // `bash -c`, so it is evaluated exactly once. Interpolating it into a
        // shell template instead would mean quoting for two levels of shell.
        //
        // `timeout` runs in the guest because that is the only thing that
        // reliably stops the work: killing ssh locally does not signal the
        // remote command over a non-tty exec channel.
        let payload = BASE64_STANDARD.encode(command);
        let remote = format!(
            "cd {} && exec timeout -k {} {} bash -c \"$(printf %s {} | base64 -d)\"",
            shlex::try_quote(&self.cwd).expect("Failed to quote cwd"),
            self.grace,
            timeout,
            payload,
        );

        let (program, options) = self.base.split_first().expect("Empty ssh invocation");
        Command::new(program)
            .args(options)
            .arg("-n")
            .arg(&remote)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .process_group(0)
            .spawn()
    }

    fn local_timeout(&self, timeout: u64) -> u64 {
        timeout + self.grace + 5
    }
}

/// Reject a caller-supplied socket path before trying to bind it.
pub fn validate_socket_path(path: &Path) -> Result<(), String> {
    if !path.is_absolute() {
        return Err(format!("must be an absolute path, got {}", path.display()));
    }
    if path.as_os_str().len() > MAX_SOCKET_PATH {
        return Err(format!(
            "is longer than {MAX_SOCKET_PATH} bytes: {}",
            path.display()
        ));
    }
    match path.parent() {
        Some(parent) if parent.is_dir() => {}
        Some(parent) => {
            return Err(format!(
                "parent directory does not exist: {}",
                parent.display()
            ));
        }
        None => return Err("has no parent directory".to_string()),
    }
    if path.exists()
        && !path
            .symlink_metadata()
            .is_ok_and(|m| m.file_type().is_socket())
    {
        return Err(format!("exists and is not a socket: {}", path.display()));
    }
    Ok(())
}

/// Returns false once the client can no longer be written to.
fn send(writer: &Mutex<UnixStream>, obj: serde_json::Value) -> bool {
    let mut line = obj.to_string();
    line.push('\n');
    // A vanished client is not an error; the command is still supervised and
    // will be torn down by the cancel watcher.
    writer.lock().unwrap().write_all(line.as_bytes()).is_ok()
}

fn stream_pipe<R: Read>(
    mut reader: R,
    kind: &'static str,
    writer: &Mutex<UnixStream>,
    events: &mpsc::Sender<PumpEvent>,
) {
    let mut buf = [0u8; 65536];
    loop {
        match reader.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => {
                // Stopping when the socket is gone matters for more than tidiness:
                // a command that leaves a background process holding the pipe open
                // would otherwise keep this thread, the pipe and a socket clone
                // alive for as long as that process runs.
                if !send(
                    writer,
                    json!({ "type": kind, "data": BASE64_STANDARD.encode(&buf[..n]) }),
                ) {
                    break;
                }
                let _ = events.send(PumpEvent::Data);
            }
        }
    }
    let _ = events.send(PumpEvent::Done);
}

/// Kills a process group at most once.
///
/// Guarded, because after the child has been reaped its pid -- and therefore its
/// process group id -- may have been recycled, and killing it then could hit an
/// unrelated process.
struct Killer {
    pgid: i32,
    reaped: Mutex<bool>,
}

impl Killer {
    fn kill(&self) {
        let reaped = self.reaped.lock().unwrap();
        if !*reaped {
            unsafe {
                libc::killpg(self.pgid, libc::SIGKILL);
            }
        }
    }

    fn mark_reaped(&self) {
        *self.reaped.lock().unwrap() = true;
    }
}

fn handle_connection(stream: UnixStream, executor: Arc<dyn Executor>) {
    let mut reader = BufReader::new(
        stream
            .try_clone()
            .expect("Failed to clone remote connection"),
    );

    // Shut the socket down at the end no matter how we leave: that both sends FIN
    // (so the client settles) and wakes the cancel watcher out of its read.
    let shutdown_handle = stream
        .try_clone()
        .expect("Failed to clone remote connection");
    let writer = Arc::new(Mutex::new(stream));

    let mut line = String::new();
    if reader.read_line(&mut line).unwrap_or(0) == 0 {
        let _ = shutdown_handle.shutdown(Shutdown::Both);
        return;
    }

    let request: Request = match serde_json::from_str(&line) {
        Ok(request) => request,
        Err(e) => {
            send(
                &writer,
                json!({"type": "error", "message": format!("malformed request: {e}")}),
            );
            let _ = shutdown_handle.shutdown(Shutdown::Both);
            return;
        }
    };

    let timeout = match request.timeout {
        Some(t) if t > 0.0 && t.is_finite() => t as u64,
        _ => DEFAULT_COMMAND_TIMEOUT,
    };

    let mut child = match executor.spawn(&request.command, timeout) {
        Ok(child) => child,
        Err(e) => {
            send(&writer, json!({"type": "error", "message": e.to_string()}));
            let _ = shutdown_handle.shutdown(Shutdown::Both);
            return;
        }
    };

    let stdout = child.stdout.take().expect("Failed to capture stdout");
    let stderr = child.stderr.take().expect("Failed to capture stderr");

    // Completion is reported over a channel rather than joined, so that a command
    // which leaves a background process holding stdout cannot delay the reply. The
    // pipes only reach EOF when *every* holder closes them, so waiting for that is
    // waiting for the orphan to exit.
    let (drained_tx, drained_rx) = mpsc::channel();
    for (pipe, kind) in [(Pipe::Out(stdout), "stdout"), (Pipe::Err(stderr), "stderr")] {
        let writer = writer.clone();
        let events = drained_tx.clone();
        thread::spawn(move || match pipe {
            Pipe::Out(r) => stream_pipe(r, kind, &writer, &events),
            Pipe::Err(r) => stream_pipe(r, kind, &writer, &events),
        });
    }
    drop(drained_tx);

    // child.id() is the process group id, because of process_group(0) above.
    let killer = Arc::new(Killer {
        pgid: child.id() as i32,
        reaped: Mutex::new(false),
    });

    // pi cancels by half-closing the socket, and only then; see onAbort in
    // pi-remote.ts. So EOF on the read side means "stop".
    let cancelled = Arc::new(AtomicBool::new(false));
    {
        let killer = killer.clone();
        let cancelled = cancelled.clone();
        thread::spawn(move || {
            let mut sink = [0u8; 256];
            loop {
                match reader.read(&mut sink) {
                    Ok(0) | Err(_) => break,
                    Ok(_) => continue,
                }
            }
            cancelled.store(true, Ordering::SeqCst);
            killer.kill();
        });
    }

    let mut timed_out = false;
    let exit_code = child
        .wait_timeout(Duration::from_secs(executor.local_timeout(timeout)))
        .expect("Failed to wait on process")
        .map_or_else(
            || {
                timed_out = true;
                killer.kill();
                let _ = child.wait();
                -1
            },
            |status| status.code().unwrap_or(-1),
        );
    killer.mark_reaped();

    // Flush whatever the command already wrote, then stop. Both pipes reaching EOF
    // is the happy path; going idle covers the case where an orphan still holds one
    // open, so that its output is dropped rather than stalling the caller.
    let cap = Instant::now() + Duration::from_secs(DRAIN_CAP_SECS);
    let mut finished = 0;
    while finished < 2 {
        let remaining = cap.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            break;
        }
        match drained_rx.recv_timeout(Duration::from_millis(DRAIN_IDLE_MS).min(remaining)) {
            Ok(PumpEvent::Done) => finished += 1,
            Ok(PumpEvent::Data) => {}
            Err(_) => break,
        }
    }

    if cancelled.load(Ordering::SeqCst) {
        // Nobody is listening any more.
    } else if timed_out || exit_code == TIMEOUT_EXIT_CODE {
        send(
            &writer,
            json!({"type": "error", "message": format!("timeout after {timeout}s")}),
        );
    } else {
        send(&writer, json!({"type": "exit", "code": exit_code}));
    }

    let _ = shutdown_handle.shutdown(Shutdown::Both);
}

/// Bind `path` and serve commands until the listener is closed.
///
/// Bind only once the sandbox is actually usable: callers use the socket's
/// existence as a readiness signal.
pub fn serve(path: &Path, executor: impl Executor) -> std::io::Result<()> {
    if path
        .symlink_metadata()
        .is_ok_and(|m| m.file_type().is_socket())
    {
        let _ = fs::remove_file(path);
    }

    let listener = UnixListener::bind(path)?;
    let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));

    let executor: Arc<dyn Executor> = Arc::new(executor);
    for conn in listener.incoming() {
        let Ok(stream) = conn else { break };
        let executor = executor.clone();
        thread::spawn(move || handle_connection(stream, executor));
    }

    let _ = fs::remove_file(path);
    Ok(())
}
