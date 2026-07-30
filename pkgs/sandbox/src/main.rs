mod bwrap;
mod mount;
mod utils;
mod vm;

use std::path::Path;
use std::process::Command;

use clap::Parser;

use mount::{Mount, MountType};
use utils::exit_code;

#[derive(Parser, Debug)]
#[command(name = "sandbox", about = "Manage NixOS lightweight sandboxes")]
struct Cli {
    /// Use bwrap backend (default)
    #[arg(long, group = "backend")]
    bwrap: bool,

    /// Use VM backend
    #[arg(long, group = "backend")]
    vm: bool,

    /// Share the current working directory
    #[arg(short = 'c', long)]
    cwd: bool,

    /// Share the current working directory read only
    #[arg(long = "ro-cwd")]
    ro_cwd: bool,

    /// Make /pwd/.git in the sandbox read only
    #[arg(short = 'g', long = "ro-git")]
    ro_git: bool,

    /// Share wayland
    #[arg(short = 'w', long)]
    wayland: bool,

    /// Share X11
    #[arg(short = 'x', long)]
    x11: bool,

    /// Share volumes, form hostpath:boxpath:ro/rw:type
    #[arg(short = 'v', long = "volume")]
    volumes: Vec<String>,

    /// Disable network
    #[arg(short = 'n', long = "no-network")]
    no_network: bool,

    /// Provide environment variables
    #[arg(short = 'e', long = "env")]
    env_vars: Vec<String>,

    /// Use a standard terminal
    #[arg(short = 'd', long = "downgrade-term")]
    downgrade_term: bool,

    /// Clear the environment variables before running
    #[arg(short = 'r', long = "reset-env")]
    reset_env: bool,

    #[arg(trailing_var_arg = true)]
    exec: Vec<String>,
}

#[derive(PartialEq, Eq)]
enum Backend {
    Bwrap,
    Vm,
}

pub fn ensure_env(key: &str) -> String {
    match std::env::var(key) {
        Ok(value) => value,
        Err(_) => {
            println!("Env var {key} is required but was not set");
            std::process::exit(1);
        }
    }
}

pub fn cwd() -> String {
    std::env::current_dir()
        .expect("failed to get the current working directory")
        .to_string_lossy()
        .into_owned()
}

fn find_symlinks(path: &Path) -> Vec<String> {
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

fn main() {
    let mut args = Cli::parse();

    let backend = if args.vm { Backend::Vm } else { Backend::Bwrap };

    if args.ro_git && !args.cwd {
        println!("Cannot specify --ro-git without --cwd");
        std::process::exit(1);
    }

    if args.cwd && args.ro_cwd {
        println!("Cannot specify --ro-cwd with --cwd");
        std::process::exit(1);
    }

    if args.exec.is_empty() {
        args.exec = vec!["bash".to_string()];
    }

    if std::env::var_os("IN_SPRRW_SANDBOX").is_some() {
        let status = Command::new(&args.exec[0])
            .args(&args.exec[1..])
            .status()
            .unwrap_or_else(|err| {
                eprintln!("{err}");
                std::process::exit(1);
            });
        std::process::exit(exit_code(&status));
    }

    let mut volume_mounts: Vec<Mount> = Vec::new();
    for v in &args.volumes {
        let components: Vec<&str> = v.split(':').collect();

        let mut ro = false;
        if components.len() >= 3 {
            match components[2] {
                "ro" => ro = true,
                "rw" => ro = false,
                other => {
                    println!("The mount {v} has invalid type {other}");
                    std::process::exit(1);
                }
            }
        }

        if components.len() < 2 {
            println!(
                "The mount {v} is missing a box path, expected the form hostpath:boxpath:ro/rw:type"
            );
            std::process::exit(1);
        }

        let mount_type = match components.get(3) {
            Some(mount_type) => MountType::parse(mount_type).unwrap_or_else(|| {
                println!("Invalid type for the mount {v} : {mount_type}");
                std::process::exit(1);
            }),
            None => MountType::Unknown,
        };

        volume_mounts.push(Mount {
            host_path: components[0].to_string(),
            box_path: components[1].to_string(),
            mount_type,
            ro,
        });
    }

    for v in &volume_mounts {
        if Path::new(&v.host_path).exists() {
            continue;
        }

        match v.mount_type {
            MountType::Unknown => {
                println!(
                    "The mount {} did not exist on the host and no type was specified to autocreate with",
                    v.host_path
                );
                std::process::exit(1);
            }
            MountType::Dir => std::fs::create_dir_all(&v.host_path)
                .unwrap_or_else(|err| panic!("failed to create {}: {err}", v.host_path)),
            MountType::File => {
                let _ = std::fs::OpenOptions::new()
                    .append(true)
                    .create(true)
                    .open(&v.host_path)
                    .unwrap_or_else(|err| panic!("failed to touch {}: {err}", v.host_path));
            }
        }
    }

    match backend {
        Backend::Bwrap => bwrap::run(&args, volume_mounts),
        Backend::Vm => vm::run(&args, volume_mounts),
    }
}
