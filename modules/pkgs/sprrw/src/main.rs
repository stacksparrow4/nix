mod config;

use std::iter;
use std::path::PathBuf;
use std::process::Command;

use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::Shell;

use config::Config;
use thiserror::Error;

#[derive(Error, Debug)]
enum ParseOverrideInputError {
    #[error("expected format NAME=VALUE")]
    InvalidFormat,
}

fn parse_override_input(raw: &str) -> Result<(String, String), ParseOverrideInputError> {
    let (name, value) = raw
        .split_once('=')
        .ok_or(ParseOverrideInputError::InvalidFormat)?;
    Ok((name.to_string(), value.to_string()))
}

#[derive(Parser, Debug)]
#[command(name = "sprrw")]
struct Cli {
    /// Absolute path to the flake to build and switch to
    #[arg(long, global = true, value_name = "PATH")]
    build_flake: Option<PathBuf>,

    /// Absolute path to a flake to update (repeatable)
    #[arg(long = "update-flake", global = true, value_name = "PATH")]
    update_flakes: Vec<PathBuf>,

    /// Override a flake input as NAME=VALUE (repeatable)
    #[arg(long = "override-input", global = true, value_name = "NAME=VALUE", value_parser=parse_override_input)]
    override_inputs: Vec<(String, String)>,

    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Build and switch to the build flake
    Build,
    /// Update the update flake's inputs, then build
    Update,
    /// Deploy a flake using deploy-rs
    Deploy,
    /// Print shell completions
    Completions { shell: Shell },
}

fn main() {
    let cli = Cli::parse();

    match Config::load(cli.build_flake, cli.update_flakes, cli.override_inputs) {
        Ok(config) => match cli.command {
            Cmd::Build => build(&config),
            Cmd::Update => {
                update(&config);
                build(&config);
            }
            Cmd::Deploy => deploy(),
            Cmd::Completions { shell } => {
                let mut cmd = Cli::command();
                let name = cmd.get_name().to_string();
                clap_complete::generate(shell, &mut cmd, name, &mut std::io::stdout());
            }
        },
        Err(e) => {
            eprintln!("{}", e);
            std::process::exit(1);
        }
    }
}

fn run_cmd(cmd: &mut Command) {
    let str_cmd = iter::once(cmd.get_program().to_string_lossy())
        .chain(cmd.get_args().map(|x| x.to_string_lossy()))
        .collect::<Vec<std::borrow::Cow<str>>>()
        .join(" ");

    println!("\x1b[32m:: {}\x1b[0m", str_cmd);

    match cmd.status() {
        Ok(status) => {
            if !status.success() {
                eprintln!(
                    "'{}' - exited with nonzero code {}",
                    cmd.get_program().to_string_lossy(),
                    status
                );
                std::process::exit(1);
            }
        }
        Err(e) => {
            eprintln!(
                "failed to run command {} - {}",
                cmd.get_program().to_string_lossy(),
                e
            );
            std::process::exit(1);
        }
    }
}

fn append_override_inputs(cmd: &mut Command, config: &Config) {
    for (name, value) in &config.override_inputs {
        cmd.arg("--override-input").arg(name).arg(value);
    }
}

fn diff_last_system_closures() {
    let mut generations: Vec<(u64, PathBuf)> = std::fs::read_dir("/nix/var/nix/profiles")
        .expect("failed to read profile directory")
        .filter_map(|entry| {
            let path = entry.ok()?.path();
            let generation = path
                .file_name()?
                .to_str()?
                .strip_prefix("system-")?
                .strip_suffix("-link")?
                .parse()
                .ok()?;
            Some((generation, path))
        })
        .collect();

    generations.sort_by_key(|(generation, _)| *generation);

    if generations.len() < 2 {
        return;
    }

    let previous = &generations[generations.len() - 2].1;
    let current = &generations[generations.len() - 1].1;

    run_cmd(
        Command::new("nix")
            .args(["store", "diff-closures"])
            .arg(previous)
            .arg(current),
    )
}

fn trim_profiles() {
    run_cmd(
        Command::new("sudo")
            .args(["nix-env", "--delete-generations", "+2", "--profile"])
            .arg("/nix/var/nix/profiles/system"),
    );
}

fn build(config: &Config) {
    for flake in &config.add_flakes {
        run_cmd(Command::new("git").arg("-C").arg(flake).args(["add", "-A"]));
    }

    if cfg!(target_os = "macos") {
        let mut cmd = Command::new("nix");
        cmd.current_dir(&config.build_flake)
            .args(["run", "home-manager/master", "--", "switch", "--show-trace"])
            .arg("--flake")
            .arg(&config.build_flake);
        append_override_inputs(&mut cmd, config);
        run_cmd(&mut cmd);
    } else {
        let mut cmd = Command::new("nixos-rebuild");
        cmd.current_dir(&config.build_flake)
            .args(["switch", "--sudo"])
            .arg("--flake")
            .arg(&config.build_flake)
            .args([
                "--option",
                "warn-dirty",
                "false",
                "--show-trace",
                "--print-build-logs",
            ]);
        append_override_inputs(&mut cmd, config);
        run_cmd(&mut cmd);

        diff_last_system_closures();
        trim_profiles();
    }
}

fn deploy() {
    run_cmd(Command::new("git").args(["add", "-A"]));

    if !Command::new("nix")
        .args([
            "run",
            ".#deploy-rs",
            "--",
            ".",
            "--",
            "--option",
            "warn-dirty",
            "false",
            "--print-build-logs",
            "--show-trace",
        ])
        .status()
        .expect("failed to execute nix run")
        .success()
    {
        println!("Failed to execute nix run .#deploy-rs.");
        println!(
            "Maybe deploy-rs is not a flake output? Here is how to add it with dendritic nix:"
        );
        println!();
        println!("flake.packages = builtins.mapAttrs (system: pkgs: {{");
        println!("  deploy-rs = pkgs.deploy-rs;");
        println!("}}) inputs.nixpkgs.legacyPackages;");
        std::process::exit(1);
    };
}

fn update(config: &Config) {
    for update_flake in &config.update_flakes {
        run_cmd(
            Command::new("nix")
                .current_dir(update_flake)
                .arg("flake")
                .arg("update")
                .arg("--flake")
                .arg(update_flake),
        );
    }
}
