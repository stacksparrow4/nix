use std::{
    env,
    process::{Child, Command, Stdio},
    thread::sleep,
    time::Duration,
};

use clap::Parser;
use tempfile::{TempDir, tempdir};

use bridge::SOCKET_NAME;

/// Serve tool calls by substituting each command into a caller-supplied template.
///
/// Only --remote / --universal-remote reach this; sandboxes (bwrap and VM alike)
/// are served by `sandbox --serve`, which speaks the same protocol from the same
/// crate.
fn start_remote_server(template: &str) -> TempDir {
    let dir = tempdir().expect("Failed to create temporary remote dir");
    let socket_path = dir.path().join(SOCKET_NAME);
    let template = template.to_string();
    std::thread::spawn(move || {
        if let Err(e) = bridge::serve(&socket_path, bridge::Template(template)) {
            eprintln!("Bridge server failed: {e}");
        }
    });
    dir
}

fn validate_remote_arg(remote_arg: &str) {
    if !bridge::Template::is_valid(remote_arg) {
        eprintln!(
            "error: --remote template must contain {}",
            bridge::CMD_PLACEHOLDER
        );
        std::process::exit(2);
    }
}

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
    #[arg(hide = true)]
    internal_real_pi_location: Option<String>,

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

const DEFAULT_EXTENSIONS: &[&str] = &["ask-mode.ts", "save.ts", "goal.ts"];
const REQUIRED_EXTENSIONS: &[&str] = &["pi-remote.ts"];
const DEFAULT_TOOLS: &[&str] = &["read", "write", "edit", "bash", "complete_goal"];
const BRIDGE_DIR: &str = "/tmp/pi-remote";

/// Start one sandbox serving tool calls, and wait for its socket to appear.
///
/// `sandbox --serve` owns the box and the transport: for the bwrap backend it runs
/// the bridge inside the box, and for `--vm` it runs on the host and forwards each
/// command into the VM. Either way it binds the socket only once the box is
/// usable, so waiting for the socket is a sufficient readiness check.
fn start_serving_sandbox(
    sandbox_args: &[String],
    no_network: bool,
    backend_args: &[&str],
) -> (TempDir, Child) {
    let dir = tempdir().expect("Failed to create temporary bridge dir");
    let socket = dir.path().join(SOCKET_NAME);

    let mut proc = Command::new("sandbox")
        .arg("--serve")
        .arg(&socket)
        .args(backend_args)
        .args(if no_network {
            vec!["--no-network"]
        } else {
            vec![]
        })
        .args(sandbox_args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .spawn()
        .expect("Failed to start tool sandbox");

    while !socket.exists() {
        if let Some(status) = proc
            .try_wait()
            .expect("Failed to poll the tool sandbox process")
        {
            eprintln!("Tool sandbox exited before it was ready ({})", status);
            std::process::exit(1);
        }

        sleep(Duration::from_millis(25));
    }

    (dir, proc)
}

/// Ask a serving sandbox to shut down and wait for it.
///
/// Must be SIGTERM rather than `Child::kill`, which sends SIGKILL: the sandbox
/// needs to run its cleanup to terminate qemu and remove its run directory.
fn terminate(proc: &mut Child) {
    unsafe {
        libc::kill(proc.id() as i32, libc::SIGTERM);
    }
    let _ = proc.wait();
}

fn main() {
    let args = Args::parse();

    let real_pi_location = args
        .internal_real_pi_location
        .expect("Missing real pi location");

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

    let universal = args.universal_remote.is_some();

    let specified_remote = args.remote.is_some() || args.universal_remote.is_some();

    let brave_search = !(args.no_brave_search || args.local.is_some());

    let all_tools: Vec<String> = args
        .tools
        .as_deref()
        .map_or(vec![], |ts| {
            ts.split(',').map(|t| t.trim().to_string()).collect()
        })
        .into_iter()
        .chain(if args.no_tools || args.search {
            vec![]
        } else if universal {
            vec!["command".to_string()]
        } else {
            DEFAULT_TOOLS.iter().map(|t| t.to_string()).collect()
        })
        .chain(if brave_search {
            Some("web_search".to_string())
        } else {
            None
        })
        .collect();

    let all_extensions: Vec<String> = args
        .extensions
        .as_deref()
        .map_or(vec![], |es| {
            es.split(',').map(|e| e.trim().to_string()).collect()
        })
        .into_iter()
        .chain(if args.no_extensions {
            vec![]
        } else {
            DEFAULT_EXTENSIONS.iter().map(|e| e.to_string()).collect()
        })
        .chain(if brave_search {
            Some("brave-search.ts".to_string())
        } else {
            None
        })
        .chain(REQUIRED_EXTENSIONS.iter().map(|e| e.to_string()))
        .collect();

    let system = args.system.unwrap_or_else(|| {
        if args.search {
            return String::from("You are a technical research assistant that searches the web to provide information. Be concise.");
        }

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

        format!(
            "You are a helpful coding assistant.\n\nGuidelines:\n{}",
            guidelines
                .into_iter()
                .map(|g| format!("- {}", g))
                .collect::<Vec<String>>()
                .join("\n")
        )
    });

    let sandbox_args: Vec<String> = if args.cwd {
        vec!["--cwd".to_string(), "--ro-git".to_string()]
    } else if args.ro_cwd {
        vec!["--ro-cwd".to_string()]
    } else {
        vec![]
    }
    .into_iter()
    .chain(
        args.volume
            .into_iter()
            .flat_map(|v| vec!["-v".to_string(), v]),
    )
    .chain(args.additional_sandbox_args.map_or(vec![], |a| {
        shlex::split(&a).expect("Invalid value for additional_sandbox_args")
    }))
    .collect();

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

    let (bridge_dir, serving_proc) = match args.remote.or(args.universal_remote) {
        // --remote / --universal-remote: we serve, running each command through
        // the caller's template on this host.
        Some(template) => (start_remote_server(&template), None),
        // Otherwise the sandbox serves, and owns the box and the transport.
        None => {
            let (dir, proc) = start_serving_sandbox(
                &sandbox_args,
                args.local.is_some(),
                if args.vm { &["--vm"] } else { &[] },
            );
            (dir, Some(proc))
        }
    };

    let bridge_args = vec![
        "-v".to_string(),
        format!("{}:{}:ro:dir", bridge_dir.path().display(), BRIDGE_DIR),
    ];

    let pi_cmd: Vec<String> = [
        real_pi_location,
        "--approve".to_string(),
        "--no-tools".to_string(),
        "--no-extensions".to_string(),
        "--offline".to_string(),
    ]
    .into_iter()
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
    .chain(["--system-prompt".to_string(), system])
    .chain(
        args.models
            .map_or(vec![], |models| vec!["--models".to_string(), models]),
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
            ]
            .into_iter()
            .flat_map(|v| vec!["-v".to_string(), v]),
        )
        .args(network_args)
        .args(bridge_args)
        .args(if universal {
            vec![]
        } else {
            vec!["--env", "PI_REMOTE_FILE_TOOLS=1"]
        })
        .args(if specified_remote {
            vec!["--env", "PI_SPECIFIED_REMOTE=1"]
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
        .args(["--downgrade-term", "--", "sh", "-c"])
        .arg(format!("{}{}", in_sandbox_shell_prefix, joined_pi_cmd))
        .status()
        .expect("Failed to launch sandboxed pi");

    if let Some(mut proc) = serving_proc {
        terminate(&mut proc);
    }

    if let Some((_, mut socat_proc)) = socat_info {
        socat_proc.kill().expect("Socat could not be killed");
    }
}
