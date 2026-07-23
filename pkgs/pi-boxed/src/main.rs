use std::{
    env,
    io::{BufRead, BufReader, Write},
    process::{Command, Stdio},
};

use clap::Parser;
use regex::Regex;
use tempfile::tempdir;

use crate::remote::{start_remote_server, validate_remote_arg};

mod remote;

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

    /// Search mode - only provide brave search
    #[arg(short, long)]
    search: bool,

    /// Print mode
    // This technically does not need pass through however keeping it here for backwards
    // compatability
    #[arg(short, long)]
    print: bool,

    // Sandbox arguments
    /// Share CWD
    #[arg(short, long)]
    cwd: bool,

    /// Share CWD read-only
    #[arg(long)]
    ro_cwd: bool,

    /// Share a volume with the sandbox. Format: <host>:<box>:<ro|rw>:<dir|file>. Can be repeated.
    #[arg(short, long)]
    volume: Vec<String>,

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
    #[arg(long)]
    system: Option<String>,

    /// Disable brave search tool and extension
    #[arg(short, long)]
    no_brave_search: bool,

    /// Execute commands on a remote host. Use the template <CMD>. The remote must be a unix/bash host.
    #[arg(long)]
    remote: Option<String>,

    /// Like --remote, but for non unix hosts. Use the template <CMD>.
    #[arg(long)]
    universal_remote: Option<String>,

    /// Execute commands inside a VM
    #[arg(long)]
    vm: bool,

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

const DEFAULT_EXTENSIONS: &[&str] = &["ask-mode.ts", "bash-tool.ts", "save.ts", "goal.ts"];
const DEFAULT_FULL_REMOTE_TOOLS: &[&str] = &["read", "write", "edit", "command", "complete_goal"];
const DEFAULT_TOOLS: &[&str] = &["read", "write", "edit", "bash", "complete_goal"];

fn main() {
    let args = Args::parse();

    if [
        args.remote.is_some(),
        args.universal_remote.is_some(),
        args.vm,
    ]
    .into_iter()
    .filter(|&x| x)
    .count()
        > 1
    {
        eprintln!("Can only specify one of --remote, --universal-remote, or --vm.");
        std::process::exit(2);
    }

    if let Some(template) = args.remote.as_ref().or(args.universal_remote.as_ref()) {
        validate_remote_arg(template);
    }

    let remote = args.remote.is_some() || args.universal_remote.is_some();
    let full_remote = args.remote.is_some() || args.vm;
    let universal = args.universal_remote.is_some();

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
        .chain(if remote || args.vm {
            Some("pi-remote.ts".to_string())
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
        .chain(if args.no_tools || args.search {
            vec![]
        } else if full_remote {
            DEFAULT_FULL_REMOTE_TOOLS
                .iter()
                .map(|x| x.to_string())
                .collect()
        } else if remote {
            vec!["command".to_string()]
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
        if args.search {
            return String::from("You are a technical research assistant that searches the web to provide information. Be concise.");
        }

        let mut s = "You are a helpful coding assistant.\n\nGuidelines:\n".to_string();

        let mut guidelines = vec![];

        if all_tools.contains(&"bash".to_string()) {
            guidelines.push("Use bash for file operations like ls, rg, find");
            guidelines.push("Avoid recalling information about source available software and instead answer definitively by cloning the source to /tmp and referring to it");
        }

        if all_tools.contains(&"read".to_string()) {
            guidelines.push("Use read to examine files instead of cat or sed");
        }

        if all_tools.contains(&"edit".to_string()) {
            guidelines.push("Use edit for precise changes (edits[].oldText must match exactly)");
            guidelines.push("When changing multiple separate locations in one file, use one edit call with multiple entries in edits[]");
            guidelines.push("Each edits[].oldText is matched against the original file, not after earlier edits are applied. Do not emit overlapping or nested edits");
        }

        if all_tools.contains(&"write".to_string()) {
            guidelines.push("Use write only for new files or complete rewrites");
        }

        if all_tools.contains(&"command".to_string()) {
            if universal {
                guidelines.push("The command tool is not necessarily bash (although this is the most common option), it could also be other shells such as Windows Powershell");
            } else {
                guidelines.push("Use the command tool for file operations like ls, rg, find");
            }
        }

        if brave_search {
            guidelines.push("Perform web searches when you are unsure of current information");
        }

        guidelines.push("Be concise in your responses");
        guidelines.push("Show file paths clearly when working with files");

        s.push_str(&guidelines.into_iter().map(|g| format!("- {}", g)).collect::<Vec<String>>().join("\n"));

        s
    });

    let (socat_info, in_sandbox_shell_prefix, network_args) = if let Some(socat_arg) =
        args.local.as_ref()
    {
        let socat_tmp_dir = tempdir().expect("Failed to create temporary socat dir");

        let socat_tmp_dir_str = socat_tmp_dir.path().to_string_lossy().to_string();

        let socat = Command::new("socat")
            .arg(format!("UNIX-LISTEN:{}/llama.sock,fork", socat_tmp_dir_str))
            .arg(socat_arg)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("Failed to start socat");

        (
            Some((socat_tmp_dir, socat)),
            "socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama/llama.sock &>/dev/null & ",
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

    let mut vm_proc = if args.vm {
        Some(
            Command::new("sandbox")
                .arg("--vm")
                .args(if args.cwd {
                    vec!["--cwd", "--ro-git"]
                } else if args.ro_cwd {
                    vec!["--ro-cwd"]
                } else {
                    vec![]
                })
                .args(args.volume.iter().flat_map(|v| vec!["-v", v]))
                .args(args.additional_sandbox_args.as_ref().map_or(vec![], |a| {
                    shlex::split(a).expect("Invalid value for additional_sandbox_args")
                }))
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .env("PYTHONUNBUFFERED", "1")
                .spawn()
                .expect("Failed to start VM box"),
        )
    } else {
        None
    };

    let remote_dir = (if args.vm {
        let vm_proc = vm_proc.as_mut().unwrap();
        let mut stdout_reader = BufReader::new(vm_proc.stdout.as_mut().unwrap());

        let mut first_line = String::new();
        let _ = stdout_reader.read_line(&mut first_line).expect("Failed to read first line of VM process");

        let re = Regex::new(r"^Forwarding SSH to port (\d+)$").unwrap();

        let ssh_port = &re.captures(first_line.trim()).expect("Failed to extract SSH port")[1];

        let starter = if args.cwd || args.ro_cwd {
            "'cd /pwd &&' "
        } else {
            ""
        };

        Some(format!("echo {starter}<CMD> | sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {ssh_port} localhost"))
    } else {
        args.remote.or(args.universal_remote)
    })
    .as_ref()
    .map(|template| start_remote_server(template));

    let remote_args = if let Some(dir) = remote_dir.as_ref() {
        vec![
            "-v".to_string(),
            format!("{}:/tmp/pi-remote:ro:dir", dir.path().to_string_lossy()),
        ]
    } else {
        vec![]
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
        .args(remote_args)
        .args(if full_remote {
            vec!["--env".to_string(), "PI_REMOTE_FILE_TOOLS=1".to_string()]
        } else {
            vec![]
        })
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
        } else if args.ro_cwd {
            vec!["--ro-cwd"]
        } else {
            vec![]
        })
        .args(args.volume.iter().flat_map(|v| vec!["-v", v.as_str()]))
        .args(args.additional_sandbox_args.map_or(vec![], |a| {
            shlex::split(&a).expect("Invalid value for additional_sandbox_args")
        }))
        .args(["--downgrade-term", "--", "sh", "-c"])
        .arg(format!("{}{}", in_sandbox_shell_prefix, joined_pi_cmd))
        .status()
        .expect("Failed to launch sandboxed pi");

    if let Some(mut vm_proc) = vm_proc {
        let _ = vm_proc
            .stdin
            .as_ref()
            .expect("Failed to obtain stdin of vm process")
            .write("exit\n".as_bytes())
            .expect("Failed to send exit message");

        let _ = vm_proc.wait().expect("Failed to wait for vm process");
    }

    if let Some((_, mut socat_proc)) = socat_info {
        socat_proc.kill().expect("Socat could not be killed");
    }
}
