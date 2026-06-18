use std::{env, process::{Command, exit}};

use clap::Parser;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    // Pass through args
    #[arg(short, long)]
    tools: Option<String>,

    #[arg(short, long)]
    prompt: Option<String>,

    // Sandbox passthrough options
    #[arg(short, long)]
    additional_sandbox_args: Option<String>,

    // TODO: add specific passthroughs for common options such as --cwd, --vm, --no-network

    // Specific args
    #[arg(short, long)]
    extensions: Option<String>,

    #[arg(short, long)]
    system: Option<String>,

    #[arg(short, long)]
    brave_search: bool,
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
        .map_or(vec![], |ts| {
            ts.split(',').map(|t| t.trim().to_string()).collect()
        })
        .into_iter()
        .chain(if args.brave_search {
            Some("web_search".to_string())
        } else {
            None
        })
        .collect();

    let pi_agent_dir = format!("{}/.pi/agent", env::home_dir().expect("Could not find home directory").to_string_lossy());
    let box_pi_agent_dir = "/home/sprrw/.pi/agent";

    let status = Command::new("sandbox")
        .args([
            format!("{}/settings.json:{}/sessions:ro:file", pi_agent_dir, box_pi_agent_dir),
            format!("{}/sessions:{}/sessions:ro:dir", pi_agent_dir, box_pi_agent_dir),
            // TODO: share models
            // TODO: SYSTEM.md
            format!("{}/skills:{}/skills:ro:dir", pi_agent_dir, box_pi_agent_dir),
            // TODO: auth.json if network is enabled, unix socket mounting if network is disabled
            // TODO: share brave search config if brave search is enabled
            // TODO: inject additional_sandbox_args
        ])
        .args([
            "--downgrade-term",
            "--ro-git", // TODO: only use with --cwd
            "--",
            "pi",
            "--approve",
            "--no-tools",
            // TODO: allowlist tools
            // TODO: allowlist models
            // TODO inherit additional positional arguments
        ]).status().expect("Failed to launch sandboxed pi");

    exit(status.code().expect("Could not retrieve status code"));
}
