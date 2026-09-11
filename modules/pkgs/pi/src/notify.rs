pub const SOCKET_NAME: &str = "notify.sock";

pub const SOCKET_PATH_IN_SANDBOX: &str = "/tmp/pi-notify/notify.sock";

#[cfg(target_os = "linux")]
pub fn start_notify_server() -> Option<tempfile::TempDir> {
    use std::{
        fs,
        io::{BufRead, BufReader},
        os::unix::{fs::PermissionsExt, net::UnixListener},
        process::{Command, Stdio},
        thread,
    };

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

                let line = line.trim_end_matches(['\n', '\r']);
                let (title, body) = match line.split_once('\t') {
                    Some((t, b)) if !t.is_empty() => (t, b),
                    _ => ("Pi", "Ready for input"),
                };

                let _ = Command::new("notify-send")
                    .args(["--app-name=pi", "--", title, body])
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .status();
            });
        }
    });

    Some(dir)
}

#[cfg(not(target_os = "linux"))]
pub fn start_notify_server() -> Option<tempfile::TempDir> {
    None
}
