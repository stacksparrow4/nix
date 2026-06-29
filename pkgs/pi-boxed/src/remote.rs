use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    os::unix::{
        fs::PermissionsExt,
        net::{UnixListener, UnixStream},
        process::CommandExt,
    },
    process::{Command, Stdio},
    sync::{Arc, Mutex},
    thread,
    time::Duration,
};

use base64::prelude::*;
use serde_json::json;
use tempfile::{TempDir, tempdir};
use wait_timeout::ChildExt;

const CMD_PLACEHOLDER: &str = "<CMD>";

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

fn handle_remote_connection(stream: UnixStream, template: String) {
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

    let quoted = shlex::try_quote(&command).expect("Failed to quote command");
    let host_cmd = template.replace(CMD_PLACEHOLDER, &quoted);

    let mut child = match Command::new("bash")
        .arg("-c")
        .arg(&host_cmd)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0)
        .spawn()
    {
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

pub fn start_remote_server(template: &str) -> TempDir {
    let dir = tempdir().expect("Failed to create temporary remote dir");
    let socket_path = dir.path().join("pi.sock");
    let template = template.to_string();
    thread::spawn(move || {
        let listener = UnixListener::bind(&socket_path).expect("Failed to bind remote socket");
        let _ = fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o600));

        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            let template = template.clone();
            thread::spawn(move || handle_remote_connection(stream, template));
        }
    });
    dir
}
