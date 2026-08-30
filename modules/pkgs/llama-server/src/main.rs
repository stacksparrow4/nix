use std::{
    fs,
    path::Path,
    process::{Command, Stdio},
    vec,
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
    #[arg(long, hide = true)]
    internal_models_dir: Option<String>,

    #[arg(long, hide = true)]
    internal_preset_ini: Option<String>,

    // Pass through args
    /// Reasoning - off or on
    #[arg(short, long)]
    reasoning: Option<String>,

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

    let _ = Command::new("podman")
        .args(["run", "--rm", "-it", "--name", "llama-cpp", "--gpus", "all"])
        .args(if let Some(model_dir) = args.internal_models_dir {
            vec!["-v".to_string(), format!("{}:/models:ro", model_dir)]
        } else {
            vec![]
        })
        .args(
            if let Some(preset_ini) = args.internal_preset_ini.as_ref() {
                vec!["-v".to_string(), format!("{}:/preset.ini:ro", preset_ini)]
            } else {
                vec![]
            },
        )
        .args(["-v", "/nix/store:/nix/store:ro"])
        .args(["-v", &format!("{}:{}", SOCKET_DIR, SOCKET_DIR)])
        .args(["--network", "none"])
        .arg(IMAGE)
        .args(["--models-dir", "/models"])
        .arg("--no-models-autoload")
        .args(["--no-warmup", "--host", SOCKET])
        .args(if args.internal_preset_ini.is_some() {
            vec!["--models-preset", "/preset.ini"]
        } else {
            vec![]
        })
        .args(if let Some(reasoning) = args.reasoning {
            vec!["--reasoning".to_string(), reasoning]
        } else {
            vec![]
        })
        .args(args.args)
        .status()
        .expect("Failed to launch llama-cpp");

    socat.kill().expect("Socat could not be killed");
    let _ = socat.wait();
}
