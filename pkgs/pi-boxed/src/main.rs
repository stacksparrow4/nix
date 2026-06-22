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

    /// Print mode
    // This technically does not need pass through however keeping it here for backwards
    // compatability
    #[arg(short, long)]
    print: bool,

    // Sandbox arguments
    /// Share CWD
    #[arg(short, long)]
    cwd: bool,

    /// Comma seperated list of allowed models
    #[arg(short, long)]
    models: Option<String>,

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

    /// Custom system prompt
    #[arg(short, long)]
    system: Option<String>,

    /// Disable brave search tool and extension
    #[arg(short, long)]
    no_brave_search: bool,

    /// Real pi location, used internally by Nix. You shouldn't need to supply this option, it will
    /// be added automatically
    internal_real_pi_location: String,

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

const DEFAULT_EXTENSIONS: &[&str] = &["ask-mode.ts", "hide-bash-body.ts"];
const DEFAULT_TOOLS: &[&str] = &["read", "write", "edit", "bash"];

fn main() {
    let args = Args::parse();

    let brave_search = !(args.no_brave_search || args.local.is_some());

    let all_extensions: Vec<String> = args
        .extensions
        .map_or(vec![], |es| {
            es.split(',').map(|e| e.trim().to_string()).collect()
        })
        .into_iter()
        .chain(if args.no_extensions {
            vec![]
        } else {
            DEFAULT_EXTENSIONS.iter().map(|x| x.to_string()).collect()
        })
        .chain(if brave_search {
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
        .chain(if args.no_tools {
            vec![]
        } else {
            DEFAULT_TOOLS.iter().map(|x| x.to_string()).collect()
        })
        .chain(if brave_search {
            Some("web_search".to_string())
        } else {
            None
        })
        .collect();

    let system = args.system.unwrap_or_else(|| {
        let mut s = "You are a helpful coding assistant.\n\nGuidelines:\n".to_string();

        let mut guidelines = vec![];

        if all_tools.contains(&"bash".to_string()) {
            guidelines.push("Use bash for file operations like ls, rg, find");
        }

        if all_tools.contains(&"read".to_string()) {
            guidelines.push("Use read to examine files instead of cat or sed.");
        }

        if all_tools.contains(&"edit".to_string()) {
            guidelines.push("Use edit for precise changes (edits[].oldText must match exactly)");
            guidelines.push("When changing multiple separate locations in one file, use one edit call with multiple entries in edits[] instead of multiple edit calls");
            guidelines.push("Each edits[].oldText is matched against the original file, not after earlier edits are applied. Do not emit overlapping or nested edits. Merge nearby changes into one edit");
            guidelines.push("Keep edits[].oldText as small as possible while still being unique in the file. Do not pad with large unchanged regions");
        }

        if all_tools.contains(&"write".to_string()) {
            guidelines.push("Use write only for new files or complete rewrites");
        }

        if brave_search {
            guidelines.push("Perform web searches when you are unsure of current information");
        }

        guidelines.push("Be concise in your responses");
        guidelines.push("Show file paths clearly when working with files");

        s.push_str(&guidelines.into_iter().map(|g| format!("- {}", g)).collect::<Vec<String>>().join("\n"));

        s
    });

    let (socat_info, in_sandbox_shell_prefix, network_args) =
        if let Some(socat_arg) = args.local.as_ref() {
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
        &args.internal_real_pi_location,
        "--approve",
        "--no-tools",
        "--no-extensions",
    ]
    .into_iter()
    .map(|s| s.to_string())
    .chain(if args.print {
        vec!["-p".to_string()]
    } else {
        vec![]
    })
    .chain(if all_tools.is_empty() {
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
    .chain(vec!["--system-prompt".to_string(), system])
    .chain(if let Some(models) = args.models {
        vec!["--models".to_string(), models]
    } else {
        vec![]
    })
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
            ]
            .into_iter()
            .flat_map(|x| vec!["-v".to_string(), x]),
        )
        .args(network_args)
        .args(if brave_search {
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
