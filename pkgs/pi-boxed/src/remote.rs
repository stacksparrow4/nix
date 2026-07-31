use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    os::unix::{
        fs::PermissionsExt,
        net::{UnixListener, UnixStream},
        process::CommandExt,
    },
    path::Path,
    process::{Child, Command, Stdio},
    sync::{Arc, Mutex},
    thread,
    time::Duration,
};

use base64::prelude::*;
use serde_json::json;
use tempfile::{TempDir, tempdir};
use wait_timeout::ChildExt;

const CMD_PLACEHOLDER: &str = "<CMD>";
pub const SOCKET_NAME: &str = "pi.sock";

/// How a command received over the bridge is turned into a process.
enum Executor {
    /// Run the command on this host by substituting it into a template (eg an ssh invocation).
    Template(String),
    /// Run the command directly, in whatever context this server itself runs in.
    Local,
}

pub fn validate_remote_arg(remote_arg: &str) {
    if !remote_arg.contains(CMD_PLACEHOLDER) {
        eprintln!("error: --remote template must contain {CMD_PLACEHOLDER}");
        std::process::exit(2);
    }
}

fn send_msg(writer: &Mutex<UnixStream>, obj: serde_json::Value) {
    let mut line = obj.to_string();
    line.push('\n');
    let _ = writer.lock().unwrap().write_all(line.as_bytes());
}

fn stream_pipe<R: Read>(mut reader: R, kind: &'static str, writer: &Mutex<UnixStream>) {
    let mut buf = [0u8; 65536];
    loop {
        match reader.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => send_msg(
                writer,
                json!({
                    "type": kind,
                    "data": BASE64_STANDARD.encode(&buf[..n]),
                }),
            ),
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

    Command::new("bash")
        .arg("-c")
        .arg(&script)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0)
        .spawn()
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

    let req: serde_json::Value = match serde_json::from_str(&line) {
        Ok(v) => v,
        Err(_) => return,
    };

    let command = req["command"]
        .as_str()
        .expect("Command was not supplied")
        .to_string();
    let timeout = req["timeout"].as_u64().unwrap_or(60);

    let mut child = match spawn_command(&executor, &command) {
        Ok(c) => c,
        Err(e) => {
            send_msg(&writer, json!({"type": "error", "message": e.to_string()}));
            return;
        }
    };

    let stdout = child.stdout.take().expect("Failed to capture stdout");
    let stderr = child.stderr.take().expect("Failed to capture stderr");

    let out_writer = writer.clone();
    let err_writer = writer.clone();
    let out_thread = thread::spawn(move || stream_pipe(stdout, "stdout", &out_writer));
    let err_thread = thread::spawn(move || stream_pipe(stderr, "stderr", &err_writer));

    let mut timed_out = false;

    let exit_code = child
        .wait_timeout(Duration::from_secs(timeout))
        .expect("Failed to wait on process")
        .map_or_else(
            || {
                timed_out = true;
                // child.id() == process group id because of process_group(0).
                unsafe {
                    libc::killpg(child.id() as i32, libc::SIGKILL);
                }
                let _ = child.wait();
                -1
            },
            |e| e.code().unwrap_or(-1),
        );

    let _ = out_thread.join();
    let _ = err_thread.join();

    if timed_out {
        send_msg(
            &writer,
            json!({"type": "error", "message": format!("timeout after {}s", timeout)}),
        );
    } else {
        send_msg(&writer, json!({"type": "exit", "code": exit_code}));
    }
}

fn accept_loop(listener: UnixListener, executor: Executor) {
    let executor = Arc::new(executor);
    for conn in listener.incoming() {
        let Ok(stream) = conn else { continue };
        let executor = executor.clone();
        thread::spawn(move || handle_remote_connection(stream, executor));
    }
}

fn bind_socket(path: &Path) -> UnixListener {
    let listener = UnixListener::bind(path).expect("Failed to bind remote socket");
    let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));
    listener
}

/// Serve commands that are executed by substituting them into `template` on this host. The returned
/// directory holds the socket and must be kept alive for as long as the bridge is needed.
pub fn start_remote_server(template: &str) -> TempDir {
    let dir = tempdir().expect("Failed to create temporary remote dir");
    let socket_path = dir.path().join(SOCKET_NAME);
    let template = template.to_string();
    thread::spawn(move || {
        let listener = bind_socket(&socket_path);
        accept_loop(listener, Executor::Template(template));
    });
    dir
}

/// Serve commands that are executed directly by this process. Used by --internal-serve, which runs
/// inside the tool sandbox so that tool calls never touch the host.
pub fn serve_local(socket_path: &str) -> ! {
    let path = Path::new(socket_path);
    let _ = fs::remove_file(path);

    let listener = bind_socket(path);
    accept_loop(listener, Executor::Local);

    std::process::exit(0);
}
