use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    net::Shutdown,
    os::{
        fd::{AsRawFd, RawFd},
        unix::{
            fs::PermissionsExt,
            net::{UnixListener, UnixStream},
            process::CommandExt,
        },
    },
    path::Path,
    process::{Child, Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::Duration,
};

use base64::prelude::*;
use serde::Deserialize;
use serde_json::json;
use tempfile::{tempdir, TempDir};
use wait_timeout::ChildExt;

pub const CMD_PLACEHOLDER: &str = "<CMD>";
pub const SOCKET_NAME: &str = "pi.sock";
pub const INTERNAL_SERVE_ENV: &str = "SPRRW_PI_INTERNAL_SERVE";

/// How a command received over the bridge is turned into a process.
enum Executor {
    /// Run the command on this host by substituting it into a template (eg an ssh invocation).
    Template(String),
    /// Run the command directly, in whatever context this server itself runs in.
    Local,
}

#[derive(Deserialize)]
struct Request {
    command: String,
    timeout: Option<f64>,
}

pub fn validate_remote_template(template: &str) -> Result<(), String> {
    if !template.contains(CMD_PLACEHOLDER) {
        return Err(format!("--remote template must contain {CMD_PLACEHOLDER}"));
    }
    Ok(())
}

fn send_msg(writer: &Mutex<UnixStream>, obj: serde_json::Value) -> bool {
    let mut line = obj.to_string();
    line.push('\n');
    writer.lock().unwrap().write_all(line.as_bytes()).is_ok()
}

fn readable(fd: RawFd, timeout_ms: libc::c_int) -> bool {
    let mut fds = [libc::pollfd {
        fd,
        events: libc::POLLIN,
        revents: 0,
    }];
    unsafe { libc::poll(fds.as_mut_ptr(), 1, timeout_ms) > 0 }
}

fn stream_pipe<R: Read + AsRawFd>(
    mut reader: R,
    kind: &'static str,
    writer: &Mutex<UnixStream>,
    stop: &AtomicBool,
) {
    let mut buf = [0u8; 65536];
    loop {
        let stopping = stop.load(Ordering::SeqCst);
        if !readable(reader.as_raw_fd(), if stopping { 0 } else { 50 }) {
            if stopping {
                break;
            }
            continue;
        }

        match reader.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => {
                if !send_msg(
                    writer,
                    json!({
                        "type": kind,
                        "data": BASE64_STANDARD.encode(&buf[..n]),
                    }),
                ) {
                    break;
                }
            }
        }
    }
}

fn kill_group(pgid: &Mutex<Option<i32>>, signal: i32) {
    if let Some(pgid) = *pgid.lock().unwrap() {
        unsafe {
            libc::killpg(pgid, signal);
        }
    }
}

fn spawn_command(executor: &Executor, command: &str) -> std::io::Result<Child> {
    let script = match executor {
        Executor::Template(template) => {
            let quoted = shlex::try_quote(command).expect("Failed to quote command");
            template.replace(CMD_PLACEHOLDER, &quoted)
        }
        Executor::Local => command.to_string(),
    };

    let mut command = Command::new("bash");
    command
        .arg("-c")
        .arg(&script)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    unsafe {
        command.pre_exec(|| {
            if libc::setsid() == -1 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }

    command.spawn()
}

fn handle_remote_connection(stream: UnixStream, executor: Arc<Executor>) {
    let mut reader = BufReader::new(
        stream
            .try_clone()
            .expect("Failed to clone remote connection"),
    );

    let writer = Arc::new(Mutex::new(stream));

    let mut line = String::new();
    if reader.read_line(&mut line).unwrap_or(0) == 0 {
        return;
    }

    let req: Request = match serde_json::from_str(&line) {
        Ok(req) => req,
        Err(e) => {
            send_msg(&writer, json!({"type": "error", "message": format!("invalid request: {e}")}));
            return;
        }
    };

    let timeout = match req.timeout.map(Duration::try_from_secs_f64).transpose() {
        Ok(timeout) => timeout,
        Err(e) => {
            send_msg(&writer, json!({"type": "error", "message": format!("invalid timeout: {e}")}));
            return;
        }
    };

    let mut child = match spawn_command(&executor, &req.command) {
        Ok(c) => c,
        Err(e) => {
            send_msg(&writer, json!({"type": "error", "message": e.to_string()}));
            return;
        }
    };

    let stdout = child.stdout.take().expect("Failed to capture stdout");
    let stderr = child.stderr.take().expect("Failed to capture stderr");

    let pgid = Arc::new(Mutex::new(Some(child.id() as i32)));
    let aborted = Arc::new(AtomicBool::new(false));

    {
        let pgid = pgid.clone();
        let aborted = aborted.clone();
        thread::spawn(move || {
            let mut buf = [0u8; 1024];
            loop {
                match reader.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(_) => {}
                }
            }
            aborted.store(true, Ordering::SeqCst);
            kill_group(&pgid, libc::SIGKILL);
        });
    }

    let stop = Arc::new(AtomicBool::new(false));

    let out_writer = writer.clone();
    let err_writer = writer.clone();
    let out_stop = stop.clone();
    let err_stop = stop.clone();
    let out_thread = thread::spawn(move || stream_pipe(stdout, "stdout", &out_writer, &out_stop));
    let err_thread = thread::spawn(move || stream_pipe(stderr, "stderr", &err_writer, &err_stop));

    let mut timed_out = false;

    let status = match timeout {
        Some(t) => child.wait_timeout(t),
        None => child.wait().map(Some),
    };

    let exit_code = match status.expect("Failed to wait on process") {
        Some(status) => status.code().unwrap_or(-1),
        None => {
            timed_out = true;
            kill_group(&pgid, libc::SIGKILL);
            let _ = child.wait();
            -1
        }
    };

    *pgid.lock().unwrap() = None;

    stop.store(true, Ordering::SeqCst);
    let _ = out_thread.join();
    let _ = err_thread.join();

    if aborted.load(Ordering::SeqCst) {
        send_msg(&writer, json!({"type": "error", "message": "aborted"}));
    } else if timed_out {
        send_msg(
            &writer,
            json!({"type": "error", "message": format!("timeout after {}s", timeout.unwrap().as_secs_f64())}),
        );
    } else {
        send_msg(&writer, json!({"type": "exit", "code": exit_code}));
    }

    let _ = writer.lock().unwrap().shutdown(Shutdown::Both);
}

fn accept_loop(listener: UnixListener, executor: Executor) {
    let executor = Arc::new(executor);
    for conn in listener.incoming() {
        let Ok(stream) = conn else { continue };
        let executor = executor.clone();
        thread::spawn(move || handle_remote_connection(stream, executor));
    }
}

pub fn bind_private_socket(path: &Path) -> Result<UnixListener, String> {
    let listener = UnixListener::bind(path)
        .map_err(|e| format!("Failed to bind socket {}: {e}", path.display()))?;
    let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));
    Ok(listener)
}

pub fn start_remote_server(template: &str) -> Result<TempDir, String> {
    let dir = tempdir().expect("Failed to create temporary remote dir");
    let listener = bind_private_socket(&dir.path().join(SOCKET_NAME))?;
    let executor = Executor::Template(template.to_string());
    thread::spawn(move || accept_loop(listener, executor));
    Ok(dir)
}

pub fn serve_local(socket_path: &str) -> Result<(), String> {
    let path = Path::new(socket_path);
    let _ = fs::remove_file(path);

    let listener = bind_private_socket(path)?;
    accept_loop(listener, Executor::Local);
    Ok(())
}
