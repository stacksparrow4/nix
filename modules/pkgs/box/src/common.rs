use clap::Parser;

use std::os::unix::process::ExitStatusExt;
use std::path::Path;
use std::process::ExitStatus;

#[derive(Parser, Debug)]
#[command(name = "box")]
pub struct Cli {
    /// Use bwrap backend (default)
    #[arg(long, group = "backend")]
    pub bwrap: bool,

    /// Use VM backend
    #[arg(long, group = "backend")]
    pub vm: bool,

    /// Share the current working directory
    #[arg(short = 'c', long)]
    pub cwd: bool,

    /// Share the current working directory read only
    #[arg(long = "ro-cwd")]
    pub ro_cwd: bool,

    /// Make /box/.git in the sandbox read only
    #[arg(short = 'g', long = "ro-git")]
    pub ro_git: bool,

    /// Share wayland
    #[arg(short = 'w', long)]
    pub wayland: bool,

    /// Share X11
    #[arg(short = 'x', long)]
    pub x11: bool,

    /// Share volumes, form hostpath:boxpath:ro/rw:type
    #[arg(short = 'v', long = "volume")]
    pub volumes: Vec<String>,

    /// Disable network
    #[arg(short = 'n', long = "no-network")]
    pub no_network: bool,

    /// Provide environment variables
    #[arg(short = 'e', long = "env")]
    pub env_vars: Vec<String>,

    /// Use a standard terminal
    #[arg(short = 'd', long = "downgrade-term")]
    pub downgrade_term: bool,

    /// Clear the environment variables before running
    #[arg(short = 'r', long = "reset-env")]
    pub reset_env: bool,

    #[arg(trailing_var_arg = true)]
    pub exec: Vec<String>,
}


pub fn find_symlinks(path: &Path) -> Vec<String> {
    let mut found = Vec::new();

    let Ok(entries) = std::fs::read_dir(path) else {
        return found;
    };

    for entry in entries.flatten() {
        let entry_path = entry.path();

        let is_symlink = entry_path.symlink_metadata().is_ok_and(|m| m.is_symlink());
        if is_symlink {
            found.push(entry_path.to_string_lossy().into_owned());
            continue;
        }

        if entry_path.is_dir() {
            found.extend(find_symlinks(&entry_path));
        }
    }

    found
}

pub fn cwd() -> String {
    std::env::current_dir()
        .expect("failed to get the current working directory")
        .to_string_lossy()
        .into_owned()
}

pub fn exit_code(status: &ExitStatus) -> i32 {
    match status.code() {
        Some(code) => code,
        None => -status.signal().unwrap_or(1),
    }
}
