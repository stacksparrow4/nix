use std::{env, process::Command};

use clap::Parser;
use tempfile::tempdir;

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

    /// Disable network, and specify a SOCAT target for the LLM connection
    #[arg(short, long)]
    local: Option<String>,

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

enum VolAccess {
    RO,
    RW,
}

fn generate_home_volume(host_path: &str, box_path: &str, a: VolAccess, t: VolType) -> String {
    format!(
        "{}/{}:/home/sprrw/{}:{}:{}",
        env::home_dir()
            .expect("Could not find home directory")
            .to_string_lossy(),
        host_path,
        box_path,
        match a {
            VolAccess::RO => "ro",
            VolAccess::RW => "rw",
        },
        match t {
            VolType::File => "file",
            VolType::Dir => "dir",
        }
    )
}

fn generate_pi_volume(host_path: &str, box_path: &str, a: VolAccess, t: VolType) -> String {
    generate_home_volume(
        &format!(".pi/agent/{}", host_path),
        &format!(".pi/agent/{}", box_path),
        a,
        t,
    )
}

fn generate_home_mirror_volume(fname: &str, a: VolAccess, t: VolType) -> String {
    generate_home_volume(fname, fname, a, t)
}

fn generate_pi_mirror_volume(fname: &str, a: VolAccess, t: VolType) -> String {
    generate_pi_volume(fname, fname, a, t)
}

fn main() {
    let args = Args::parse();

    assert!(
        !(args.brave_search && args.local.is_some()),
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

    let (socat_info, in_sandbox_shell_prefix, network_args) = if let Some(socat_arg) = args.local {
        let socat_tmp_dir = tempdir().expect("Failed to create temporary socat dir");

        let socat_tmp_dir_str = socat_tmp_dir.path().to_string_lossy().to_string();

        let socat = Command::new("socat")
            .arg(format!("UNIX-LISTEN:{}/llama.sock,fork", socat_tmp_dir_str))
            .arg(socat_arg)
            .spawn()
            .expect("Failed to start socat");

        (
            Some((socat_tmp_dir, socat)),
            "socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama/llama.sock & ",
            vec![
                "--no-network".to_string(),
                "-v".to_string(),
                format!("{}:/tmp/llama:ro:dir", socat_tmp_dir_str),
            ],
        )
    } else {
        (
            None,
            "",
            vec![
                "-v".to_string(),
                generate_pi_mirror_volume("auth.json", VolAccess::RW, VolType::File),
            ],
        )
    };

    let pi_cmd: Vec<String> = [
        "pi-unsandboxed",
        "--approve",
        "--no-tools",
        "--no-extensions",
    ]
    .into_iter()
    .map(|s| s.to_string())
    .chain(if all_tools.len() == 0 {
        vec![]
    } else {
        vec!["--tools".to_string(), all_tools.join(",")]
    })
    .chain(all_extensions.into_iter().flat_map(|e| {
        vec![
            "-e".to_string(),
            format!("/home/sprrw/.pi/agent/extensions/{}", e),
        ]
    }))
    .chain(
        args.models
            .map_or(vec![], |m| vec!["--models".to_string(), m]),
    )
    .chain(args.args)
    .collect();

    let joined_pi_cmd = shlex::try_join(pi_cmd.iter().map(|s| s.as_str()))
        .expect("Failed to create shell script for pi_cmd");

    let _ = Command::new("sandbox")
        .args(
            [
                generate_pi_mirror_volume("settings.json", VolAccess::RW, VolType::File),
                generate_pi_mirror_volume("models.json", VolAccess::RO, VolType::File),
                generate_pi_mirror_volume("sessions", VolAccess::RW, VolType::Dir),
                generate_pi_mirror_volume("skills", VolAccess::RO, VolType::Dir),
                generate_pi_mirror_volume("extensions", VolAccess::RO, VolType::Dir),
                generate_pi_volume(
                    &format!("system/{}.md", system),
                    "SYSTEM.md",
                    VolAccess::RO,
                    VolType::File,
                ),
            ]
            .into_iter()
            .flat_map(|x| vec!["-v".to_string(), x]),
        )
        .args(network_args)
        .args(if args.brave_search {
            vec![
                "-v".to_string(),
                generate_home_mirror_volume(".config/brave-search", VolAccess::RO, VolType::Dir),
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
        .args(["--downgrade-term", "--", "sh", "-c"])
        .arg(format!("{}{}", in_sandbox_shell_prefix, joined_pi_cmd))
        .status()
        .expect("Failed to launch sandboxed pi");

    if let Some((_, mut socat_proc)) = socat_info {
        socat_proc.kill().expect("Socat could not be killed");
    }
}
