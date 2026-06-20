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
    /// Share CWD
    #[arg(short, long)]
    cwd: bool,

    /// Use VM
    #[arg(short, long)]
    vm: bool,

    /// Disable network
    #[arg(short, long)]
    no_network: bool,

    /// Pass options directly to the sandbox
    #[arg(long)]
    additional_sandbox_args: Option<String>,

    // Specific args
    /// Disable extensions by default
    #[arg(long)]
    no_extensions: bool,

    /// Specify which extensions to use
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

enum VolType {
    File,
    Dir,
}

fn generate_home_volume(host_path: &str, box_path: &str, t: VolType) -> String {
    format!(
        "{}/{}:/home/sprrw/{}:ro:{}",
        env::home_dir()
            .expect("Could not find home directory")
            .to_string_lossy(),
        host_path,
        box_path,
        match t {
            VolType::File => "file",
            VolType::Dir => "dir",
        }
    )
}

fn generate_pi_volume(host_path: &str, box_path: &str, t: VolType) -> String {
    generate_home_volume(
        &format!(".pi/agent/{}", host_path),
        &format!(".pi/agent/{}", box_path),
        t,
    )
}

fn generate_home_mirror_volume(fname: &str, t: VolType) -> String {
    generate_home_volume(fname, fname, t)
}

fn generate_pi_mirror_volume(fname: &str, t: VolType) -> String {
    generate_pi_volume(fname, fname, t)
}

fn main() {
    let args = Args::parse();

    assert!(
        !(args.brave_search && args.no_network),
        "Cannot have --no-network and --brave-search"
    );

    let all_extensions: Vec<String> = args
        .extensions
        .map_or(
            if args.no_extensions {
                vec![]
            } else {
                ["ask-mode.ts", "hide-bash-body.ts"]
                    .into_iter()
                    .map(|x| x.to_string())
                    .collect()
            },
            |es| es.split(',').map(|e| e.trim().to_string()).collect(),
        )
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

    let system = args.system.unwrap_or("code".to_string());

    let status = Command::new("sandbox")
        .args(
            [
                generate_pi_mirror_volume("settings.json", VolType::File),
                generate_pi_mirror_volume("models.json", VolType::File),
                generate_pi_mirror_volume("sessions", VolType::Dir),
                generate_pi_mirror_volume("skills", VolType::Dir),
                generate_pi_mirror_volume("extensions", VolType::Dir),
                generate_pi_volume(&format!("system/{}.md", system), "SYSTEM.md", VolType::File),
            ]
            .into_iter()
            .flat_map(|x| vec!["-v".to_string(), x]),
        )
        .args(if args.no_network {
            vec![] // TODO: unix socket mounting if network is disabled
        } else {
            vec![
                "-v".to_string(),
                generate_pi_mirror_volume("auth.json", VolType::File),
            ]
        })
        .args(if args.brave_search {
            vec![
                "-v".to_string(),
                generate_home_mirror_volume(".config/brave-search", VolType::Dir),
            ]
        } else {
            vec![]
        })
        .args(if args.cwd {
            vec!["--cwd", "--ro-git"]
        } else {
            vec![]
        })
        .args(args.additional_sandbox_args.map_or(vec![], |a| {
            shlex::split(&a).expect("Invalid value for additional_sandbox_args")
        }))
        .args([
            "--downgrade-term",
            "--",
            "pi-unsandboxed",
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
                format!("/home/sprrw/.pi/agent/extensions/{}", e),
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
