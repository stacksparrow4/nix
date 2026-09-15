use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::Shutdown;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio, exit};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

const SOCKET_NAME: &str = "clip.sock";
const SANDBOX_SOCKET_DIR: &str = "/tmp/sprrw-clip";

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

    let shim = env::var("SPRRW_CLIP_SHIM").expect("SPRRW_CLIP_SHIM is not set");

    let raw_args: Vec<String> = env::args().skip(1).collect();
    let (share_dir, vim_args) = compute_share(raw_args);

    let tmp = make_tmp_dir();
    start_clip_server(&tmp);
    let sandbox_socket = format!("{SANDBOX_SOCKET_DIR}/{SOCKET_NAME}");

    let status = Command::new("box")
        .current_dir(&share_dir)
        .arg("--cwd")
        .arg("--wayland")
        .arg("--ro-git")
        .arg("-v")
        .arg(format!("{}:{}:ro:dir", tmp.display(), SANDBOX_SOCKET_DIR))
        .arg("-e")
        .arg(format!("SPRRW_CLIPBOARD_SOCKET={sandbox_socket}"))
        .arg("-e")
        .arg(format!("SPRRW_CLIPBOARD_SHIM={shim}"))
        .arg("--")
        .arg(&nvim)
        .args(&vim_args)
        .status()
        .expect("failed to launch box");

    let _ = fs::remove_dir_all(&tmp);
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

fn make_tmp_dir() -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time went backwards")
        .as_nanos();
    let dir = env::temp_dir().join(format!("sprrw-clip-{}-{}", std::process::id(), nanos));
    fs::create_dir_all(&dir).expect("failed to create clipboard temp dir");
    let _ = fs::set_permissions(&dir, fs::Permissions::from_mode(0o700));
    dir
}

fn start_clip_server(dir: &Path) {
    let socket_path = dir.join(SOCKET_NAME);
    let listener = UnixListener::bind(&socket_path).expect("failed to bind clipboard socket");
    let _ = fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o600));

    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle(stream));
        }
    });
}

fn handle(stream: UnixStream) {
    let Ok(read_half) = stream.try_clone() else {
        return;
    };
    let mut reader = BufReader::new(read_half);

    let mut op = String::new();
    if reader.read_line(&mut op).unwrap_or(0) == 0 {
        return;
    }

    match op.trim_end_matches(['\n', '\r']) {
        "copy" => {
            let mut data = Vec::new();
            if reader.read_to_end(&mut data).is_err() {
                return;
            }
            let (cmd, args) = copy_command();
            if let Ok(mut child) = Command::new(cmd)
                .args(args)
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
            let _ = stream.shutdown(Shutdown::Both);
        }
        "paste" => {
            let (cmd, args) = paste_command();
            let output = Command::new(cmd).args(args).stderr(Stdio::null()).output();
            let mut stream = stream;
            if let Ok(output) = output {
                let _ = stream.write_all(&output.stdout);
            }
            let _ = stream.flush();
            let _ = stream.shutdown(Shutdown::Both);
        }
        _ => {}
    }
}

fn copy_command() -> (&'static str, &'static [&'static str]) {
    if cfg!(target_os = "macos") {
        ("pbcopy", &[])
    } else {
        ("wl-copy", &[])
    }
}

fn paste_command() -> (&'static str, &'static [&'static str]) {
    if cfg!(target_os = "macos") {
        ("pbpaste", &[])
    } else {
        ("wl-paste", &["--no-newline"])
    }
}
