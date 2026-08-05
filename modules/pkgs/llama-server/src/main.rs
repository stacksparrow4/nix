use std::{
    fs,
    path::Path,
    process::{Command, Stdio},
};

use clap::Parser;

const IMAGE: &str = "ghcr.io/ggml-org/llama.cpp:server-cuda13";
const SOCKET_DIR: &str = "/tmp/llama-cpp";
const SOCKET: &str = "/tmp/llama-cpp/llama.sock";
const PORT: u16 = 8033;

/// llama.cpp server wrapper. Serves every model in the Nix generated models directory in router
/// mode, reachable on port 8033. To pass extra arguments to llama-server itself, use
/// llama-server -- <ARGS>
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Enable reasoning
    #[arg(short, long)]
    reasoning: bool,

    /// Override the default context size
    #[arg(short, long)]
    context: Option<u64>,

    /// Models directory, used internally by Nix. You shouldn't need to supply this option, it will
    /// be added automatically
    internal_models_dir: String,

    /// Default context size, used internally by Nix. You shouldn't need to supply this option, it
    /// will be added automatically
    internal_default_context: u64,

    /// Additional arguments for llama-server, pass these after --
    args: Vec<String>,
}

fn main() {
    let args = Args::parse();

    if Path::new(SOCKET).exists() {
        let _ = fs::remove_file(SOCKET);
    }
    fs::create_dir_all(SOCKET_DIR).expect("Failed to create socket directory");

    let mut socat = Command::new("socat")
        .arg(format!("TCP-LISTEN:{},reuseaddr,fork", PORT))
        .arg(format!("UNIX-CONNECT:{}", SOCKET))
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("Failed to start socat");

    let context = args.context.unwrap_or(args.internal_default_context);

    let _ = Command::new("podman")
        .args(["run", "--rm", "-it", "--name", "llama-cpp", "--gpus", "all"])
        .args([
            "-v".to_string(),
            format!("{}:/models:ro", args.internal_models_dir),
        ])
        .args(["-v", "/nix/store:/nix/store:ro"])
        .args(["-v", &format!("{}:{}", SOCKET_DIR, SOCKET_DIR)])
        .args(["--network", "none"])
        .arg(IMAGE)
        .args(["--models-dir", "/models"])
        .arg("--no-models-autoload")
        .args(["--no-warmup", "--host", SOCKET])
        .args(["--reasoning", if args.reasoning { "on" } else { "off" }])
        .args(["-c", &context.to_string()])
        .args(args.args)
        .status()
        .expect("Failed to launch llama-cpp");

    socat.kill().expect("Socat could not be killed");
    let _ = socat.wait();
}
