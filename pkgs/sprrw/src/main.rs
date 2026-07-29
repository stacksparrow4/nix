mod config;

use std::path::{Path, PathBuf};
use std::process::Command;

use clap::{Parser, Subcommand};

use config::{Config, FileConfig};

const PROFILE_DIR: &str = "/nix/var/nix/profiles";

#[derive(Parser, Debug)]
#[command(
    name = "sprrw",
    about = "Build and update the sprrw nix flakes",
    version
)]
struct Cli {
    /// Absolute path to the flake to build and switch to
    #[arg(long, global = true, value_name = "PATH")]
    build_flake: Option<PathBuf>,

    /// Absolute path to the flake to update
    #[arg(long, global = true, value_name = "PATH")]
    update_flake: Option<PathBuf>,

    /// Absolute path to a flake to `git add -A` before building (repeatable)
    #[arg(long = "add-flake", global = true, value_name = "PATH")]
    add_flakes: Vec<PathBuf>,

    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Build and switch to the build flake
    Build,
    /// Update the update flake's inputs, then build
    Update,
}

fn main() {
    let cli = Cli::parse();

    if let Err(err) = run(cli) {
        eprintln!("sprrw: {err}");
        std::process::exit(1);
    }
}

fn run(cli: Cli) -> Result<(), String> {
    let file = FileConfig::load()?;
    let config = Config::resolve(cli.build_flake, cli.update_flake, cli.add_flakes, file)?;

    match cli.command {
        Cmd::Build => build(&config),
        Cmd::Update => {
            update(&config)?;
            build(&config)
        }
    }
}

fn build(config: &Config) -> Result<(), String> {
    for flake in &config.add_flakes {
        println!(":: git add -A in {}", flake.display());
        run_cmd(Command::new("git").arg("-C").arg(flake).args(["add", "-A"]))?;
    }

    println!(":: switching to {}", config.build_flake.display());
    if cfg!(target_os = "macos") {
        run_cmd(
            Command::new("nix")
                .current_dir(&config.build_flake)
                .args(["run", "home-manager/master", "--", "switch", "--show-trace"])
                .arg("--flake")
                .arg(&config.build_flake),
        )?;
    } else {
        run_cmd(
            Command::new("nixos-rebuild")
                .current_dir(&config.build_flake)
                .args(["switch", "--sudo"])
                .arg("--flake")
                .arg(&config.build_flake)
                .args([
                    "--option",
                    "warn-dirty",
                    "false",
                    "--show-trace",
                    "--print-build-logs",
                ]),
        )?;

        diff_last_system_closures()?;
    }

    trim_history()
}

fn update(config: &Config) -> Result<(), String> {
    let pkgs_dir = config.update_flake.join("pkgs");
    let pkgs_update = pkgs_dir.join("update.sh");
    if pkgs_update.is_file() {
        println!(":: running {}", pkgs_update.display());
        run_cmd(Command::new(&pkgs_update).current_dir(&pkgs_dir))?;
    }

    println!(":: nix flake update in {}", config.update_flake.display());
    run_cmd(
        Command::new("nix")
            .current_dir(&config.update_flake)
            .arg("flake")
            .arg("update")
            .arg("--flake")
            .arg(&config.update_flake),
    )
}

fn trim_history() -> Result<(), String> {
    let home = std::env::var_os("HOME").ok_or("HOME is not set")?;
    let home = PathBuf::from(home);
    let hm_profile = home.join(".local/state/nix/profiles/home-manager");

    if cfg!(target_os = "macos") {
        println!(":: trimming {}", hm_profile.display());
        return trim_profile(&hm_profile, false);
    }

    for profile in [
        PathBuf::from(PROFILE_DIR).join("system"),
        hm_profile,
        home.join(".local/state/nix/profiles/profile"),
    ] {
        println!(":: trimming {}", profile.display());
        trim_profile(&profile, true)?;
    }

    Ok(())
}

fn trim_profile(profile: &Path, sudo: bool) -> Result<(), String> {
    if !profile.exists() {
        println!("   (skipping, does not exist)");
        return Ok(());
    }

    let mut cmd = if sudo {
        let mut cmd = Command::new("sudo");
        cmd.arg("nix-env");
        cmd
    } else {
        Command::new("nix-env")
    };

    cmd.args(["--delete-generations", "+2", "--profile"])
        .arg(profile);

    run_cmd(&mut cmd)
}

fn diff_last_system_closures() -> Result<(), String> {
    let mut generations: Vec<(u64, PathBuf)> = std::fs::read_dir(PROFILE_DIR)
        .map_err(|err| format!("failed to read {PROFILE_DIR}: {err}"))?
        .filter_map(|entry| {
            let path = entry.ok()?.path();
            let name = path.file_name()?.to_str()?;
            let generation = name.strip_prefix("system-")?.strip_suffix("-link")?;
            Some((generation.parse().ok()?, path))
        })
        .collect();

    generations.sort_by_key(|(generation, _)| *generation);

    if generations.len() < 2 {
        return Ok(());
    }

    let previous = &generations[generations.len() - 2].1;
    let current = &generations[generations.len() - 1].1;

    println!(":: closure diff");
    run_cmd(
        Command::new("nix")
            .args(["store", "diff-closures"])
            .arg(previous)
            .arg(current),
    )
}

fn run_cmd(cmd: &mut Command) -> Result<(), String> {
    let status = cmd.status().map_err(|err| {
        format!(
            "failed to run {}: {err}",
            cmd.get_program().to_string_lossy()
        )
    })?;

    if !status.success() {
        return Err(format!(
            "{} exited with {status}",
            cmd.get_program().to_string_lossy()
        ));
    }

    Ok(())
}
