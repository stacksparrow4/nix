use clap::{ArgAction, Parser, ValueEnum};

#[derive(Copy, Clone, PartialEq, Eq, ValueEnum)]
pub enum Backend {
    Bwrap,
    Podman,
    Vm,
}

/// Manage NixOS lightweight sandboxes
#[derive(Parser)]
#[command(version, about, long_about = None)]
pub struct Args {
    /// Use bwrap backend (default)
    #[arg(long, group = "backend")]
    pub bwrap: bool,

    /// Use podman backend
    #[arg(long, group = "backend")]
    pub podman: bool,

    /// Use VM backend
    #[arg(long, group = "backend")]
    pub vm: bool,

    /// Share the current working directory
    #[arg(short, long)]
    pub cwd: bool,

    /// Share the current working directory read only
    #[arg(long = "ro-cwd")]
    pub ro_cwd: bool,

    /// Make /pwd/.git in the sandbox read only
    #[arg(short = 'g', long = "ro-git")]
    pub ro_git: bool,

    /// Share wayland
    #[arg(short, long)]
    pub wayland: bool,

    /// Share X11
    #[arg(short, long)]
    pub x11: bool,

    /// Share volumes, form hostpath:boxpath:ro/rw:type
    #[arg(short = 'v', long = "volume", action = ArgAction::Append)]
    pub volumes: Vec<String>,

    /// Disable network
    #[arg(short = 'n', long = "no-network")]
    pub no_network: bool,

    /// Provide environment variables
    #[arg(short = 'e', long = "env", action = ArgAction::Append)]
    pub env_vars: Vec<String>,

    /// Use a standard terminal
    #[arg(short = 'd', long = "downgrade-term")]
    pub downgrade_term: bool,

    /// Clear the environment variables before running
    #[arg(short = 'r', long = "reset-env")]
    pub reset_env: bool,

    /// VM backend: memory in MiB
    #[arg(long = "vm-memory", default_value_t = 8192)]
    pub vm_memory: u32,

    /// VM backend: number of vCPUs. Keep well under nproc; several sandboxes may
    /// run concurrently
    #[arg(long = "vm-cpus", default_value_t = 2)]
    pub vm_cpus: u32,

    /// VM backend: seconds to wait for the VM to become reachable
    #[arg(long = "vm-timeout", default_value_t = 120.0)]
    pub vm_timeout: f64,

    /// VM backend: attach an interactive serial console instead of connecting
    /// over SSH, for debugging boot problems. Quit with Ctrl-A x
    #[arg(long = "vm-console")]
    pub vm_console: bool,

    /// Keep one sandbox alive and serve commands into it over a unix socket at
    /// SOCKET, instead of running a command interactively. The socket is bound
    /// only once the sandbox is ready, so its existence can be used as a
    /// readiness signal
    #[arg(long, value_name = "SOCKET")]
    pub serve: Option<String>,

    /// Internal: this is how --serve runs the bridge inside a bwrap sandbox
    #[arg(long = "serve-agent", value_name = "SOCKET", hide = true)]
    pub serve_agent: Option<String>,

    /// Internal: shuttle stdin/stdout to a unix socket, used as an ssh
    /// ProxyCommand so that no external forwarder is needed
    #[arg(long, value_name = "SOCKET", hide = true)]
    pub proxy: Option<String>,

    #[arg(trailing_var_arg = true)]
    pub exec: Vec<String>,
}

impl Args {
    pub fn backend(&self) -> Backend {
        if self.podman {
            Backend::Podman
        } else if self.vm {
            Backend::Vm
        } else {
            Backend::Bwrap
        }
    }

    /// Where commands run inside the box.
    pub fn box_cwd(&self) -> &'static str {
        if self.cwd || self.ro_cwd {
            "/pwd"
        } else {
            "/home/sprrw"
        }
    }
}
