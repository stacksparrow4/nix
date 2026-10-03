use std::collections::{BTreeMap, BTreeSet};
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};

use crate::run_cmd;

type Perms = BTreeMap<String, BTreeSet<String>>;

fn cmd_output(cmd: &mut Command) -> String {
    match cmd.stderr(Stdio::inherit()).output() {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).into_owned()
        }
        Ok(output) => {
            eprintln!(
                "'{}' - exited with nonzero code {}",
                cmd.get_program().to_string_lossy(),
                output.status
            );
            std::process::exit(1);
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

fn parse_perms(keyfile: &str) -> Perms {
    let mut perms = Perms::new();
    let mut group = "";
    for line in keyfile.lines().map(str::trim) {
        if let Some(g) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
            group = g;
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        match (group, key) {
            ("Session Bus Policy" | "System Bus Policy", _) => {
                perms.entry(group.into()).or_default().insert(line.into());
            }
            ("Context", "shared" | "sockets" | "devices" | "features" | "filesystems")
            | ("USB Devices", "enumerable-devices") => {
                let items = value.split(';').filter(|i| !i.is_empty()).map(String::from);
                perms.entry(key.into()).or_default().extend(items);
            }
            _ => {}
        }
    }
    perms
}

fn perm_name<'a>(category: &str, item: &'a str) -> &'a str {
    let item = item.trim_start_matches('!');
    if category == "filesystems" {
        match item.rsplit_once(':') {
            Some((path, "ro" | "rw" | "create")) => path,
            _ => item,
        }
    } else {
        item.split_once('=').map_or(item, |(name, _)| name)
    }
}

fn confirm() -> bool {
    print!("Allow? [y/N] ");
    let _ = std::io::stdout().flush();
    let mut answer = String::new();
    let _ = std::io::stdin().read_line(&mut answer);
    answer.trim().eq_ignore_ascii_case("y")
}

pub fn update() {
    run_cmd(Command::new("flatpak").args(["update", "--system", "-y", "--runtime"]));

    let home = PathBuf::from(std::env::var_os("HOME").expect("HOME env var not set"));
    let override_dirs = [
        PathBuf::from("/var/lib/flatpak/overrides"),
        home.join(".local/share/flatpak/overrides"),
    ];

    let pending = cmd_output(Command::new("flatpak").args([
        "remote-ls",
        "--system",
        "--updates",
        "--app",
        "--columns=ref,origin",
    ]));

    for line in pending.lines() {
        let Some((app_ref, origin)) = line.split_once('\t') else {
            continue;
        };
        let app_id = app_ref.split('/').nth(1).unwrap_or(app_ref);

        let commit = cmd_output(Command::new("flatpak").args([
            "remote-info",
            "--system",
            "--show-commit",
            origin,
            app_ref,
        ]));
        let commit = commit.trim();
        let new = parse_perms(&cmd_output(Command::new("flatpak").args([
            "remote-info",
            "--system",
            &format!("--commit={commit}"),
            "--show-metadata",
            origin,
            app_ref,
        ])));
        let old = parse_perms(&cmd_output(Command::new("flatpak").args([
            "info",
            "--system",
            "--show-metadata",
            app_ref,
        ])));

        let mut overrides = Perms::new();
        for path in override_dirs
            .iter()
            .flat_map(|dir| [dir.join("global"), dir.join(app_id)])
        {
            for (category, items) in parse_perms(&std::fs::read_to_string(path).unwrap_or_default())
            {
                overrides.entry(category).or_default().extend(items);
            }
        }

        let changed: Vec<_> = new
            .iter()
            .flat_map(|(category, items)| items.iter().map(move |item| (category, item)))
            .filter(|(category, item)| {
                let unchanged = old.get(*category).is_some_and(|o| o.contains(*item));
                let overridden = overrides.get(*category).is_some_and(|o| {
                    o.iter()
                        .any(|i| perm_name(category, i) == perm_name(category, item))
                });
                !unchanged && !overridden
            })
            .collect();

        if !changed.is_empty() {
            println!("\x1b[33m:: {app_id} has permission changes:\x1b[0m");
            for (category, item) in &changed {
                println!("   {category}: {item}");
            }
            if !confirm() {
                println!("Skipping {app_id}");
                continue;
            }
        }

        // Requires sudo because flatpak doesn't let you update to a commit without root
        run_cmd(Command::new("sudo").args([
            "flatpak",
            "update",
            "--system",
            "-y",
            &format!("--commit={commit}"),
            app_ref,
        ]));
    }
}
