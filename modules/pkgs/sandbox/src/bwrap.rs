use std::path::Path;
use std::process::Command;

use crate::mount::{BOX_CWD, Mount, MountType};
use crate::utils::exit_code;
use crate::{Cli, cwd, ensure_env, find_symlinks};

const HOME_FILES: &str = "/etc/hm-package/home-files";

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let mut mounts: Vec<Mount> = find_symlinks(Path::new(HOME_FILES))
        .iter()
        .map(|f| {
            let relative = f.strip_prefix(&format!("{HOME_FILES}/")).unwrap_or(f);
            Mount::new(f, &format!("/home/sprrw/{relative}"), MountType::File, true)
        })
        .collect();

    mounts.extend(volume_mounts);

    if args.cwd {
        mounts.push(Mount::new(&cwd(), BOX_CWD, MountType::Dir, false));
    }

    if args.ro_cwd {
        mounts.push(Mount::new(&cwd(), BOX_CWD, MountType::Dir, true));
    }

    if args.ro_git && Path::new("./.git").exists() {
        mounts.push(Mount::new(
            &format!("{}/.git", cwd()),
            &format!("{BOX_CWD}/.git"),
            MountType::Dir,
            true,
        ));
    }

    let wayland = args.wayland
        && std::env::var("XDG_RUNTIME_DIR").is_ok()
        && std::env::var("WAYLAND_DISPLAY").is_ok();

    if wayland {
        mounts.push(Mount::new(
            &format!(
                "{}/{}",
                ensure_env("XDG_RUNTIME_DIR"),
                ensure_env("WAYLAND_DISPLAY")
            ),
            "/tmp/wayland-1",
            MountType::File,
            true,
        ));
    }

    if args.x11 {
        mounts.push(Mount::new(
            "/tmp/.X11-unix",
            "/tmp/.X11-unix",
            MountType::Dir,
            true,
        ));
    }

    mounts.extend([
        Mount::new("/bin", "/bin", MountType::Dir, true),
        Mount::new("/etc", "/etc", MountType::Dir, true),
        Mount::new("/usr", "/usr", MountType::Dir, true),
        Mount::new("/lib64", "/lib64", MountType::Dir, true),
        Mount::new(
            "/run/current-system/sw",
            "/run/current-system/sw",
            MountType::Dir,
            true,
        ),
        Mount::new(
            "/home/sprrw/nixos",
            "/home/sprrw/nixos",
            MountType::Dir,
            true,
        ),
    ]);

    let mut envvars: Vec<String> = args.env_vars.clone();
    envvars.extend(
        [
            format!(
                "PATH={}/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
                if args.reset_env {
                    String::new()
                } else {
                    format!("{}:", ensure_env("PATH"))
                }
            ),
            "__ETC_PROFILE_SOURCED=1".to_string(),
            "IN_SPRRW_SANDBOX=1".to_string(),
            "HOME=/home/sprrw".to_string(),
            "COLORTERM=truecolor".to_string(),
            "TEMPDIR=/tmp".to_string(),
            "TMPDIR=/tmp".to_string(),
            "TEMP=/tmp".to_string(),
            "TMP=/tmp".to_string(),
        ]
        .into_iter()
        .chain(std::env::var("EDITOR").map(|e| format!("EDITOR={}", e)))
        .chain(std::env::var("NIX_PATH").map(|np| format!("NIX_PATH={}", np))),
    );

    if args.downgrade_term || std::env::var("TERM").is_err() {
        envvars.push("TERM=xterm-256color".to_string());
    } else {
        envvars.push(format!("TERM={}", ensure_env("TERM")));
    }

    if wayland {
        envvars.extend([
            "WAYLAND_DISPLAY=wayland-1".to_string(),
            "XDG_RUNTIME_DIR=/tmp".to_string(),
            format!("GTK_THEME={}", ensure_env("GTK_THEME")),
        ]);
    }

    if args.x11 && std::env::var("DISPLAY").is_ok() {
        envvars.push(format!("DISPLAY={}", ensure_env("DISPLAY")));
    }

    let mut subprocess_args: Vec<String> = [
        "--unshare-all",
        "--as-pid-1",
        "--die-with-parent",
        "--tmpfs",
        "/tmp",
        "--proc",
        "/proc",
        "--dev",
        "/dev",
        "--dir",
        "/home/sprrw",
        "--ro-bind",
        "/nix/store",
        "/nix/store",
    ]
    .iter()
    .map(|a| a.to_string())
    .collect();

    if !args.no_network {
        subprocess_args.push("--share-net".to_string());
    }

    subprocess_args.push("--chdir".to_string());
    subprocess_args.push(
        if args.cwd || args.ro_cwd {
            BOX_CWD
        } else {
            "/home/sprrw"
        }
        .to_string(),
    );

    for m in &mounts {
        subprocess_args.extend(m.to_bwrap_args());
    }

    subprocess_args.push("/usr/bin/env".to_string());
    subprocess_args.extend(envvars);
    subprocess_args.extend(args.exec.clone());

    let mut command = Command::new("bwrap");
    command.args(&subprocess_args);
    if args.reset_env {
        command.env_clear();
    }

    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(err) => {
            println!("{err}");
            std::process::exit(1);
        }
    };

    // Must happen after the spawn, as an ignored SIGINT is inherited through the exec
    unsafe { libc::signal(libc::SIGINT, libc::SIG_IGN) };

    match child.wait() {
        Ok(status) => std::process::exit(exit_code(&status)),
        Err(err) => {
            println!("{err}");
            let _ = child.kill();
            let _ = child.wait();
            std::process::exit(1)
        }
    }
}
