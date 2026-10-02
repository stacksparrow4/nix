use std::{
    fs,
    io::{BufRead, BufReader},
    os::unix::{fs::PermissionsExt, net::UnixListener},
    process::{Command, Stdio},
    thread,
};

pub const SOCKET_NAME: &str = "notify.sock";

pub const SOCKET_PATH_IN_SANDBOX: &str = "/tmp/pi-notify/notify.sock";

#[cfg(target_os = "linux")]
fn build_notify_command(title: &str, body: &str) -> Command {
    let mut cmd = Command::new("notify-send");
    cmd.arg(format!(
        "--icon={}",
        std::env::var("SPRRW_PI_NOTIFY_ICON").unwrap()
    ));
    cmd.args(["--app-name=", "--", title, body]);
    cmd
}

#[cfg(target_os = "macos")]
fn build_notify_command(title: &str, body: &str) -> Command {
    let mut cmd = Command::new("terminal-notifier");
    cmd.args(["-title", title, "-message", body]);
    cmd.args(["-appIcon", &std::env::var("SPRRW_PI_NOTIFY_ICON").unwrap()]);
    cmd
}

pub fn start_notify_server() -> Option<tempfile::TempDir> {
    let dir = tempfile::tempdir().expect("Failed to create temporary notify dir");
    let socket_path = dir.path().join(SOCKET_NAME);

    thread::spawn(move || {
        let listener = UnixListener::bind(&socket_path).expect("Failed to bind notify socket");
        let _ = fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o600));

        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || {
                let mut reader = BufReader::new(stream);
                let mut line = String::new();
                if reader.read_line(&mut line).unwrap_or(0) == 0 {
                    return;
                }

                let line = line.trim_end();
                let (title, body) = line.split_once('\t').unwrap_or(("Pi turn complete", ""));

                let _ = build_notify_command(title, body)
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .status();
            });
        }
    });

    Some(dir)
}
