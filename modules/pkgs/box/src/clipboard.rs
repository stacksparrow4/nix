//! Host side of the `--clipboard` bridge.
//!
//! When clipboard sharing is enabled, `box` starts a small listener on the host
//! and injects `wl-copy`/`wl-paste` shims plus `SPRRW_CLIPBOARD_ADDR` into the
//! sandbox (see `container.rs`). The shims talk the simple protocol below and we
//! translate each request into the host's native clipboard tools:
//!   * Linux: `wl-copy` / `wl-paste` (MIME aware, supports the primary selection)
//!   * macOS: `pbcopy` / `pbpaste` (text only)
//!
//! Transport is a Unix socket on Linux and TCP on macOS, matching how each
//! backend can reach the host.

use std::io::{Read, Write};
use std::net::TcpListener;
use std::os::unix::net::UnixListener;
use std::process::{Command, Stdio};
use std::thread;

use crate::mount::{Mount, MountType};

/// Box path the Unix socket is bind-mounted to inside the sandbox.
const BOX_SOCKET_PATH: &str = "/tmp/sprrw-clipboard.sock";

/// What `box` needs to hand to a backend after starting the bridge.
pub struct Bridge {
    /// `SPRRW_CLIPBOARD_ADDR=...` env var to expose inside the sandbox.
    pub addr_env: String,
    /// Optional mount (the Unix socket) to add to the sandbox.
    pub mount: Option<Mount>,
}

/// Start a Unix-socket bridge (Linux: bwrap and Linux docker).
pub fn start_unix() -> Bridge {
    // A unique directory under the host /tmp that we intentionally leak: the
    // listener thread lives for the whole lifetime of this `box` process and the
    // socket must outlive this function. The stale socket (a few bytes) is
    // cleaned up with /tmp.
    let dir = std::env::temp_dir().join(format!("sprrw-clip.{}", std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    let sock_path = dir.join("clip.sock");
    let _ = std::fs::remove_file(&sock_path);

    let listener = UnixListener::bind(&sock_path)
        .unwrap_or_else(|e| panic!("failed to bind clipboard socket {sock_path:?}: {e}"));

    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle(stream));
        }
    });

    Bridge {
        addr_env: format!("SPRRW_CLIPBOARD_ADDR=unix:{BOX_SOCKET_PATH}"),
        mount: Some(Mount::new(
            &sock_path.to_string_lossy(),
            BOX_SOCKET_PATH,
            MountType::File,
            false,
        )),
    }
}

/// Start a TCP bridge (macOS docker, and the Linux VM backend).
///
/// `host` is how the sandbox reaches the host: `host.docker.internal` for
/// docker, `10.0.2.2` for the QEMU user network.
pub fn start_tcp(host: &str) -> Bridge {
    let listener = TcpListener::bind("127.0.0.1:0").expect("failed to bind clipboard socket");
    let port = listener
        .local_addr()
        .expect("failed to read clipboard socket address")
        .port();

    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle(stream));
        }
    });

    Bridge {
        addr_env: format!("SPRRW_CLIPBOARD_ADDR=tcp:{host}:{port}"),
        mount: None,
    }
}

fn handle<S: Read + Write>(mut stream: S) {
    // Read the newline-terminated header.
    let mut header = Vec::new();
    let mut byte = [0u8; 1];
    loop {
        match stream.read(&mut byte) {
            Ok(0) => break,
            Ok(_) if byte[0] == b'\n' => break,
            Ok(_) => header.push(byte[0]),
            Err(_) => return,
        }
    }

    let header = String::from_utf8_lossy(&header);
    let mut parts = header.split_whitespace();
    let op = parts.next().unwrap_or_default();
    let selection = parts.next().unwrap_or("c");
    let mime = parts.next().unwrap_or_default();
    let primary = selection == "p";

    match op {
        "copy" => {
            let mut data = Vec::new();
            if stream.read_to_end(&mut data).is_err() {
                return;
            }
            host_copy(primary, mime, &data);
        }
        "paste" => {
            let data = host_paste(primary, mime);
            let _ = stream.write_all(&data);
            let _ = stream.flush();
        }
        "list" => {
            let data = host_list(primary);
            let _ = stream.write_all(&data);
            let _ = stream.flush();
        }
        _ => {}
    }
}

#[cfg(target_os = "macos")]
fn host_copy(_primary: bool, _mime: &str, data: &[u8]) {
    run_with_input("pbcopy", &[], data);
}

#[cfg(target_os = "macos")]
fn host_paste(_primary: bool, mime: &str) -> Vec<u8> {
    // Only text is supported through pbpaste.
    if mime.is_empty() || mime.starts_with("text/") {
        run_capture("pbpaste", &[]).unwrap_or_default()
    } else {
        Vec::new()
    }
}

#[cfg(target_os = "macos")]
fn host_list(_primary: bool) -> Vec<u8> {
    match run_capture("pbpaste", &[]) {
        Some(out) if !out.is_empty() => b"text/plain\n".to_vec(),
        _ => Vec::new(),
    }
}

#[cfg(not(target_os = "macos"))]
fn host_copy(primary: bool, mime: &str, data: &[u8]) {
    let mut args: Vec<&str> = Vec::new();
    if primary {
        args.push("--primary");
    }
    if !mime.is_empty() {
        args.push("--type");
        args.push(mime);
    }
    run_with_input("wl-copy", &args, data);
}

#[cfg(not(target_os = "macos"))]
fn host_paste(primary: bool, mime: &str) -> Vec<u8> {
    let mut args: Vec<&str> = Vec::new();
    if primary {
        args.push("--primary");
    }
    if !mime.is_empty() {
        args.push("--type");
        args.push(mime);
    }
    run_capture("wl-paste", &args).unwrap_or_default()
}

#[cfg(not(target_os = "macos"))]
fn host_list(primary: bool) -> Vec<u8> {
    let mut args: Vec<&str> = vec!["--list-types"];
    if primary {
        args.push("--primary");
    }
    run_capture("wl-paste", &args).unwrap_or_default()
}

fn run_with_input(cmd: &str, args: &[&str], data: &[u8]) {
    let Ok(mut child) = Command::new(cmd)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    else {
        return;
    };
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(data);
    }
    let _ = child.wait();
}

fn run_capture(cmd: &str, args: &[&str]) -> Option<Vec<u8>> {
    Command::new(cmd)
        .args(args)
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| o.stdout)
}
