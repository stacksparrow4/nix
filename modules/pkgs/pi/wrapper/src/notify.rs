use std::{
    io::{BufRead, BufReader},
    path::Path,
    process::{Command, Stdio},
    thread,
};

use tempfile::{TempDir, tempdir};

use crate::{
    remote::bind_private_socket,
    volumes::{self, VolAccess, VolType, volume},
};

const SOCKET_NAME: &str = "notify.sock";
const SANDBOX_DIR: &str = "/tmp/pi-notify";

fn handle_connection<S: std::io::Read>(stream: S) {
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    if reader.read_line(&mut line).unwrap_or(0) == 0 {
        return;
    }

    let line = line.trim_end_matches(['\n', '\r']);
    let (title, body) = line.split_once('\t').unwrap_or(("Pi", ""));

    let _ = build_notify_command(title, body)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn notify_icon(title: &str) -> String {
    if title == "Warming pi cache"
        && let Ok(icon) = std::env::var("SPRRW_PI_NOTIFY_ICON_CACHE_WARM")
    {
        return icon;
    }
    std::env::var("SPRRW_PI_NOTIFY_ICON").unwrap()
}

fn build_notify_command(title: &str, body: &str) -> Command {
    let mut cmd = Command::new("notify-send");
    cmd.arg(format!("--icon={}", notify_icon(title)));
    cmd.args(["--app-name=", "--", title, body]);
    cmd
}

pub fn box_args(dir: &Path) -> Vec<String> {
    let mut args: Vec<String> = volume(dir.display(), SANDBOX_DIR, VolAccess::Ro, VolType::Dir).into();
    args.extend(volumes::env(
        "PI_NOTIFY_SOCKET",
        format!("{SANDBOX_DIR}/{SOCKET_NAME}"),
    ));
    args
}

pub fn start_notify_server() -> Result<TempDir, String> {
    let dir = tempdir().expect("Failed to create temporary notify dir");
    let listener = bind_private_socket(&dir.path().join(SOCKET_NAME))?;

    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle_connection(stream));
        }
    });

    Ok(dir)
}
