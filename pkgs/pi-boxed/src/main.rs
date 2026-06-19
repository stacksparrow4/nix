use std::{
    env,
    process::{Command, exit},
};

use clap::Parser;

/// Pi sandbox wrapper. For Pi help, use pi -- --help
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    // Pass through args
    /// Disable tools by default
    #[arg(long)]
    no_tools: bool,

    /// Specify which tools to use
    #[arg(short, long)]
    tools: Option<String>,

    /// Specify models enabled for Ctrl+P cycling
    #[arg(short, long)]
    models: Option<String>,

    /// Print mode
    #[arg(short, long)]
    print: bool,

    // Sandbox arguments
    /// Pass options directly to the sandbox
    #[arg(long)]
    additional_sandbox_args: Vec<String>,

    // TODO: add specific passthroughs for common options such as --cwd, --vm, --no-network

    // Specific args
    /// Extensions to enable
    #[arg(short, long)]
    extensions: Option<String>,

    /// System prompt file name to use
    #[arg(short, long)]
    system: Option<String>,

    /// Enable brave search tool and extension
    #[arg(short, long)]
    brave_search: bool,

    /// Positional arguments for Pi
    args: Vec<String>,
}

fn get_pi_agent_dir() -> String {
    format!(
        "{}/.pi/agent",
        env::home_dir()
            .expect("Could not find home directory")
            .to_string_lossy()
    )
}

const BOX_PI_AGENT_DIR: &str = "/home/sprrw/.pi/agent";

enum VolType {
    File,
    Dir,
}

fn generate_pi_volume(host_path: &str, box_path: &str, t: VolType) -> String {
    format!(
        "{}/{}:{}/{}:ro:{}",
        get_pi_agent_dir(),
        host_path,
        BOX_PI_AGENT_DIR,
        box_path,
        match t {
            VolType::File => "file",
            VolType::Dir => "dir",
        }
    )
}

fn generate_mirror_volume(fname: &str, t: VolType) -> String {
    generate_pi_volume(fname, fname, t)
}

fn main() {
    let args = Args::parse();

    let all_extensions: Vec<String> = args
        .extensions
        .map_or(vec![], |es| {
            es.split(',').map(|e| e.trim().to_string()).collect()
        })
        .into_iter()
        .chain(if args.brave_search {
            Some("brave-search.ts".to_string())
        } else {
            None
        })
        .collect();

    let all_tools: Vec<String> = args
        .tools
        .map_or(
            if args.no_tools {
                vec![]
            } else {
                ["read", "write", "edit", "bash"]
                    .into_iter()
                    .map(|x| x.to_string())
                    .collect()
            },
            |ts| ts.split(',').map(|t| t.trim().to_string()).collect(),
        )
        .into_iter()
        .chain(if args.brave_search {
            Some("web_search".to_string())
        } else {
            None
        })
        .collect();

    let system = args.system.unwrap_or("system-code.md".to_string());

    let status = Command::new("sandbox")
        .args([
            generate_mirror_volume("settings.json", VolType::File),
            generate_mirror_volume("models.json", VolType::File),
            generate_mirror_volume("sessions", VolType::Dir),
            generate_mirror_volume("skills", VolType::Dir),
            generate_mirror_volume("extensions", VolType::Dir),
            generate_pi_volume(&system, "SYSTEM.md", VolType::File),
            generate_mirror_volume("auth.json", VolType::File),
            // TODO: auth.json if network is enabled, unix socket mounting if network is disabled
            // TODO: share brave search config if brave search is enabled
        ])
        .args(args.additional_sandbox_args)
        .args([
            "--downgrade-term",
            "--ro-git", // TODO: only use with --cwd
            "--",
            "pi",
            "--approve",
            "--no-tools",
            "--no-extensions",
        ])
        .args(if all_tools.len() == 0 {
            vec![]
        } else {
            vec!["--tools".to_string(), all_tools.join(",")]
        })
        .args(all_extensions.into_iter().flat_map(|e| {
            vec![
                "-e".to_string(),
                format!("{}/extensions/{}", BOX_PI_AGENT_DIR, e),
            ]
        }))
        .args(
            args.models
                .map_or(vec![], |m| vec!["--models".to_string(), m]),
        )
        .args(args.args)
        .status()
        .expect("Failed to launch sandboxed pi");

    exit(status.code().unwrap_or(1));
}
