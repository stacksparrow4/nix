use std::{
    io::{BufRead, BufReader},
    process::{Command, Stdio},
    thread,
};

pub const SOCKET_NAME: &str = "notify.sock";

pub const SOCKET_PATH_IN_SANDBOX: &str = "/tmp/pi-notify/notify.sock";

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
    if title == "Warming pi cache" {
        if let Ok(icon) = std::env::var("SPRRW_PI_NOTIFY_ICON_CACHE_WARM") {
            return icon;
        }
    }
    std::env::var("SPRRW_PI_NOTIFY_ICON").unwrap()
}

#[cfg(target_os = "linux")]
fn build_notify_command(title: &str, body: &str) -> Command {
    let mut cmd = Command::new("notify-send");
    cmd.arg(format!("--icon={}", notify_icon(title)));
    cmd.args(["--app-name=", "--", title, body]);
    cmd
}

#[cfg(target_os = "macos")]
fn build_notify_command(title: &str, body: &str) -> Command {
    let mut cmd = Command::new("terminal-notifier");
    cmd.args(["-title", title, "-message", body]);
    cmd.args(["-appIcon", &notify_icon(title)]);
    cmd
}

pub enum NotifyServer {
    #[cfg(target_os = "linux")]
    Unix(tempfile::TempDir),
    #[cfg(not(target_os = "linux"))]
    Tcp(String),
}

impl NotifyServer {
    pub fn box_args(&self) -> Vec<String> {
        match self {
            #[cfg(target_os = "linux")]
            NotifyServer::Unix(dir) => {
                let socket_mount_dir = std::path::Path::new(SOCKET_PATH_IN_SANDBOX)
                    .parent()
                    .unwrap()
                    .to_string_lossy()
                    .to_string();
                vec![
                    "-v".to_string(),
                    format!("{}:{}:ro:dir", dir.path().display(), socket_mount_dir),
                    "--env".to_string(),
                    format!("PI_NOTIFY_SOCKET={}", SOCKET_PATH_IN_SANDBOX),
                ]
            }
            #[cfg(not(target_os = "linux"))]
            NotifyServer::Tcp(addr) => vec![
                "--env".to_string(),
                format!("PI_NOTIFY_ADDR={}", addr),
            ],
        }
    }
}

#[cfg(target_os = "linux")]
pub fn start_notify_server() -> Option<NotifyServer> {
    use std::fs;
    use std::os::unix::{fs::PermissionsExt, net::UnixListener};

    let dir = tempfile::tempdir().expect("Failed to create temporary notify dir");
    let socket_path = dir.path().join(SOCKET_NAME);

    thread::spawn(move || {
        let listener = UnixListener::bind(&socket_path).expect("Failed to bind notify socket");
        let _ = fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o600));

        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle_connection(stream));
        }
    });

    Some(NotifyServer::Unix(dir))
}

#[cfg(not(target_os = "linux"))]
pub fn start_notify_server() -> Option<NotifyServer> {
    use std::net::TcpListener;

    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind notify socket");
    let port = listener
        .local_addr()
        .expect("Failed to read notify socket address")
        .port();

    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(stream) = conn else { continue };
            thread::spawn(move || handle_connection(stream));
        }
    });

    Some(NotifyServer::Tcp(format!("host.docker.internal:{port}")))
}
