//! Command bridge server. Client: common/home/ai/pi/extensions/pi-remote.ts
//!
//! One command per connection, newline-delimited JSON over a unix socket:
//!
//! ```text
//! -> {"command": "...", "timeout": <seconds>|null}
//! <- {"type": "stdout"|"stderr", "data": "<base64>"}   streamed, repeated
//! <- {"type": "exit", "code": <int>} | {"type": "error", "message": "..."}
//! ```
//!
//! The client settles only on socket close, and detects timeouts with
//! `/^timeout/i` against the error message.

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

/// Must match SOCKET_PATH in pi-remote.ts.
pub const SOCKET_NAME: &str = "pi.sock";

pub const DEFAULT_COMMAND_TIMEOUT: u64 = 60;

/// sun_path, excluding the NUL terminator.
pub const MAX_SOCKET_PATH: usize = 107;

pub const CMD_PLACEHOLDER: &str = "<CMD>";

/// coreutils `timeout` exit status when it killed the command.
const TIMEOUT_EXIT_CODE: i32 = 124;

const DRAIN_IDLE_MS: u64 = 250;
const DRAIN_CAP_SECS: u64 = 2;

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

pub trait Executor: Send + Sync + 'static {
    fn spawn(&self, command: &str, timeout: u64) -> std::io::Result<Child>;

    /// Executors enforcing the timeout remotely need slack on the local wait.
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
        .process_group(0)
        .spawn()
}

/// Runs commands in this process's own context, ie inside the sandbox.
pub struct Local;

impl Executor for Local {
    fn spawn(&self, command: &str, _timeout: u64) -> std::io::Result<Child> {
        spawn_script(command)
    }
}

/// Runs commands on this host through a caller-supplied template.
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
    /// Full ssh invocation, no command.
    pub base: Vec<String>,
    pub cwd: String,
    /// Seconds between SIGTERM and SIGKILL in the guest.
    pub grace: u64,
}

impl Executor for Ssh {
    fn spawn(&self, command: &str, timeout: u64) -> std::io::Result<Child> {
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

/// Kills a process group, never after the pid could have been recycled.
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

    let killer = Arc::new(Killer {
        pgid: child.id() as i32,
        reaped: Mutex::new(false),
    });

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

/// Callers treat the socket's existence as a readiness signal, so bind only once
/// the sandbox is usable.
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
