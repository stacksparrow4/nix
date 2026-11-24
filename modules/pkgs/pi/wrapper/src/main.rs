use clap::{CommandFactory, Parser};
use clap_complete::Shell;

use crate::plan::Plan;
use crate::session::Session;

mod backend;
mod config;
mod local_net;
mod models;
mod notes;
mod notify;
mod plan;
mod prompt;
mod remote;
mod session;
mod settings;
mod vm;
mod volumes;

/// Pi sandbox wrapper. For Pi help, use pi -- --help
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Generate shell completions for the given shell
    #[arg(long, value_name = "SHELL")]
    completions: Option<Shell>,

    /// Share CWD
    #[arg(short, long, conflicts_with = "ro_cwd")]
    cwd: bool,

    /// Share CWD read-only
    #[arg(long)]
    ro_cwd: bool,

    /// Make AGENTS.md from the host CWD available to the agent, even without --cwd
    #[arg(short, long)]
    agents: bool,

    /// Share a volume with the sandbox. Format: <host>:<box>:<ro|rw>:<dir|file>. Can be repeated.
    #[arg(short, long)]
    volume: Vec<String>,

    /// Disable network, and specify a SOCAT target for the LLM connection
    #[arg(short, long)]
    local: Option<String>,

    /// Pass options directly to the sandbox
    #[arg(long)]
    additional_sandbox_args: Option<String>,

    /// Execute commands on a remote host.
    /// Use the template <CMD>. The remote must be a unix/bash host.
    #[arg(long, conflicts_with = "vm")]
    remote: Option<remote::RemoteTemplate>,

    /// Execute commands inside a VM
    #[arg(long)]
    vm: bool,

    /// Disable tools by default
    #[arg(long)]
    no_tools: bool,

    /// Comma separated list of tools to use
    #[arg(short, long, value_delimiter = ',')]
    tools: Vec<String>,

    /// Search mode - only provide brave search
    #[arg(short, long)]
    search: bool,

    /// Bare mode - provide almost nothing
    #[arg(short, long)]
    bare: bool,

    /// Comma separated list of allowed models
    #[arg(short, long, value_delimiter = ',')]
    models: Vec<models::ModelName>,

    /// Disable extensions by default
    #[arg(long)]
    no_extensions: bool,

    /// Comma separated list of extensions to use
    #[arg(short, long, value_delimiter = ',')]
    extensions: Vec<String>,

    /// Custom system prompt
    #[arg(long)]
    system: Option<String>,

    /// Disable brave search tool and extension
    #[arg(long)]
    no_brave_search: bool,

    /// Mount the named notes store at /notes (~/.pi/notes/<NAME>)
    #[arg(short, long, value_name = "NAME")]
    notes: Option<notes::NotesName>,

    /// Positional arguments passed directly to Pi
    args: Vec<String>,
}

fn main() {
    if let Err(e) = run(Args::parse()) {
        eprintln!("{e}");
        std::process::exit(1);
    }
}

fn run(args: Args) -> Result<(), String> {
    if let Some(shell) = args.completions {
        let mut cmd = Args::command();
        let name = cmd.get_name().to_string();
        clap_complete::generate(shell, &mut cmd, name, &mut std::io::stdout());
        return Ok(());
    }

    if let Ok(socket_path) = std::env::var(remote::INTERNAL_SERVE_ENV) {
        return remote::serve_local(&socket_path);
    }

    let plan = Plan::from_args(args)?;
    let session = Session::start(&plan)?;
    session.launch(&plan)
}
