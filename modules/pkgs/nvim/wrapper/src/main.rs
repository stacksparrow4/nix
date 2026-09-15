use std::env;
use std::path::{Path, PathBuf};
use std::process::{Command, exit};

#[cfg(not(target_os = "linux"))]
use std::io::{Read, Write};
#[cfg(not(target_os = "linux"))]
use std::net::TcpListener;
#[cfg(not(target_os = "linux"))]
use std::process::Stdio;
#[cfg(not(target_os = "linux"))]
use std::thread;

fn main() {
    let nvim = env::var("SPRRW_NVIM").expect("SPRRW_NVIM is not set");

    if env::var("IN_SPRRW_SANDBOX").as_deref() == Ok("1") {
        let args: Vec<String> = env::args().skip(1).collect();
        let status = Command::new(&nvim)
            .args(&args)
            .status()
            .expect("failed to run neovim");
        exit(status.code().unwrap_or(1));
    }

    let raw_args: Vec<String> = env::args().skip(1).collect();
    let (share_dir, vim_args) = compute_share(raw_args);

    let mut cmd = Command::new("box");
    cmd.current_dir(&share_dir)
        .arg("--cwd")
        .arg("--wayland")
        .arg("--ro-git");

    add_clipboard_bridge(&mut cmd);

    let status = cmd
        .arg("--")
        .arg(&nvim)
        .args(&vim_args)
        .status()
        .expect("failed to launch box");

    exit(status.code().unwrap_or(1));
}

fn compute_share(args: Vec<String>) -> (PathBuf, Vec<String>) {
    let cwd = env::current_dir().expect("failed to get current working directory");

    if args.len() == 1 && args[0].starts_with('/') {
        let path = Path::new(&args[0]);
        if path.is_dir() {
            return (path.to_path_buf(), vec![".".to_string()]);
        }
        let dir = path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .map(Path::to_path_buf)
            .unwrap_or(cwd);
        let file = path
            .file_name()
            .map(|f| f.to_string_lossy().into_owned())
            .unwrap_or_else(|| args[0].clone());
        return (dir, vec![file]);
    }

    (cwd, args)
}

#[cfg(target_os = "linux")]
fn add_clipboard_bridge(_cmd: &mut Command) {}

#[cfg(not(target_os = "linux"))]
fn add_clipboard_bridge(cmd: &mut Command) {
    let shim = env::var("SPRRW_CLIP_SHIM").expect("SPRRW_CLIP_SHIM is not set");

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

    cmd.arg("-e")
        .arg(format!("SPRRW_CLIPBOARD_ADDR=tcp:host.docker.internal:{port}"))
        .arg("-e")
        .arg(format!("SPRRW_CLIPBOARD_SHIM={shim}"));
}

#[cfg(not(target_os = "linux"))]
fn handle<S: Read + Write>(mut stream: S) {
    let mut op = Vec::new();
    let mut byte = [0u8; 1];
    loop {
        match stream.read(&mut byte) {
            Ok(0) => break,
            Ok(_) if byte[0] == b'\n' => break,
            Ok(_) => op.push(byte[0]),
            Err(_) => return,
        }
    }

    match String::from_utf8_lossy(&op).trim_end_matches('\r') {
        "copy" => {
            let mut data = Vec::new();
            if stream.read_to_end(&mut data).is_err() {
                return;
            }
            if let Ok(mut child) = Command::new("pbcopy")
                .stdin(Stdio::piped())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    let _ = stdin.write_all(&data);
                }
                let _ = child.wait();
            }
        }
        "paste" => {
            if let Ok(output) = Command::new("pbpaste").stderr(Stdio::null()).output() {
                let _ = stream.write_all(&output.stdout);
            }
            let _ = stream.flush();
        }
        _ => {}
    }
}
