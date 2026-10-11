use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::thread;

use crate::mount::Mount;

const ADDR_ENV: &str = "SPRRW_CLIPBOARD_ADDR";

pub const DUMMY_DISPLAY: &str = "sprrw-clipboard";

pub struct Bridge {
    pub addr_env: String,
    pub mount: Option<Mount>,
    _dir: Option<tempfile::TempDir>,
}

pub fn start_unix(box_socket_path: &str) -> Bridge {
    use std::os::unix::fs::PermissionsExt;
    use std::os::unix::net::UnixListener;

    use crate::mount::MountType;

    let dir = tempfile::Builder::new()
        .prefix("sprrw-clip.")
        .tempdir()
        .expect("failed to create the clipboard socket directory");
    let sock_path = dir.path().join("clip.sock");

    let listener = UnixListener::bind(&sock_path)
        .unwrap_or_else(|e| panic!("failed to bind clipboard socket {sock_path:?}: {e}"));
    let _ = std::fs::set_permissions(&sock_path, std::fs::Permissions::from_mode(0o600));

    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle(stream));
        }
    });

    Bridge {
        addr_env: format!("{ADDR_ENV}=unix:{box_socket_path}"),
        mount: Some(Mount::new(
            &sock_path.to_string_lossy(),
            box_socket_path,
            MountType::File,
            false,
        )),
        _dir: Some(dir),
    }
}

#[cfg(not(target_os = "linux"))]
pub fn start_tcp(host: &str) -> Bridge {
    use std::net::TcpListener;

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
        addr_env: format!("{ADDR_ENV}=tcp:{host}:{port}"),
        mount: None,
        _dir: None,
    }
}

fn handle<S: Read + Write>(mut stream: S) {
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
    let primary = parts.next().unwrap_or("c") == "p";
    let mime = parts.next().unwrap_or_default();

    match op {
        "copy" => {
            let mut data = Vec::new();
            if stream.read_to_end(&mut data).is_err() {
                return;
            }
            host_copy(primary, mime, &data);
        }
        "paste" => {
            let _ = stream.write_all(&host_paste(primary, mime));
            let _ = stream.flush();
        }
        "list" => {
            let _ = stream.write_all(&host_list(primary));
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
    if mime.is_empty() || mime == "text" || mime.starts_with("text/") {
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
fn wl_args(primary: bool, mime: &str) -> Vec<&str> {
    let mut args = Vec::new();
    if primary {
        args.push("--primary");
    }
    if !mime.is_empty() {
        args.extend(["--type", mime]);
    }
    args
}

#[cfg(not(target_os = "macos"))]
fn host_copy(primary: bool, mime: &str, data: &[u8]) {
    run_with_input("wl-copy", &wl_args(primary, mime), data);
}

#[cfg(not(target_os = "macos"))]
fn host_paste(primary: bool, mime: &str) -> Vec<u8> {
    run_capture("wl-paste", &wl_args(primary, mime)).unwrap_or_default()
}

#[cfg(not(target_os = "macos"))]
fn host_list(primary: bool) -> Vec<u8> {
    let mut args = vec!["--list-types"];
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
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| o.stdout)
}
