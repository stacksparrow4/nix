use std::{
    env,
    fs,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use clap::{CommandFactory, Parser};
use clap_complete::Shell;

const IMAGE: &str = "ghcr.io/ggml-org/llama.cpp:server-cuda13";
const SOCKET_DIR: &str = "/tmp/llama-cpp";
const SOCKET: &str = "/tmp/llama-cpp/llama.sock";
const PORT: u16 = 8033;

/// llama.cpp server wrapper
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Generate shell completions for the given shell
    #[arg(long, value_name = "SHELL")]
    completions: Option<Shell>,

    /// Serve this GGUF file only
    #[arg(short, long, value_name = "GGUF")]
    model: Option<PathBuf>,

    // Pass through args
    /// Additional arguments for llama-server, pass these after --
    args: Vec<String>,
}

fn main() {
    let args = Args::parse();

    if let Some(shell) = args.completions {
        let mut cmd = Args::command();
        let name = cmd.get_name().to_string();
        clap_complete::generate(shell, &mut cmd, name, &mut std::io::stdout());
        return;
    }

    let mut mounts: Vec<String> = Vec::new();
    let mut server_args: Vec<String> = Vec::new();

    if let Some(model) = args.model.as_ref() {
        let model = fs::canonicalize(model).unwrap_or_else(|e| {
            eprintln!("Failed to resolve model {}: {}", model.display(), e);
            std::process::exit(1);
        });
        if !model.is_file() {
            eprintln!("Model {} is not a file", model.display());
            std::process::exit(1);
        }
        let file_name = model
            .file_name()
            .expect("Model path has no file name")
            .to_string_lossy()
            .into_owned();
        let container_path = format!("/model/{}", file_name);
        mounts.extend([
            "-v".to_string(),
            format!("{}:{}:ro", model.display(), container_path),
        ]);
        server_args.extend(["-m".to_string(), container_path]);
    } else {
        if let Ok(models_dir) = env::var("LLAMA_SERVER_MODELS_DIR") {
            mounts.extend(["-v".to_string(), format!("{}:/models:ro", models_dir)]);
        }
        server_args.extend(["--models-dir".to_string(), "/models".to_string()]);
        server_args.push("--no-models-autoload".to_string());
        if let Ok(preset_ini) = env::var("LLAMA_SERVER_PRESET_INI") {
            mounts.extend(["-v".to_string(), format!("{}:/preset.ini:ro", preset_ini)]);
            server_args.extend(["--models-preset".to_string(), "/preset.ini".to_string()]);
        }
    }

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
        .args(&mounts)
        .args(["-v", "/nix/store:/nix/store:ro"])
        .args(["-v", &format!("{}:{}", SOCKET_DIR, SOCKET_DIR)])
        .args(["--network", "none"])
        .arg(IMAGE)
        .args(["--no-warmup", "--host", SOCKET])
        .args(&server_args)
        .args(["-fa", "on", "-ctk", "q8_0", "-ctv", "q8_0"])
        .args(args.args)
        .status()
        .expect("Failed to launch llama-cpp");

    socat.kill().expect("Socat could not be killed");
    let _ = socat.wait();
}
