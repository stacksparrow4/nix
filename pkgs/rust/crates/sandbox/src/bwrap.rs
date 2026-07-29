use std::{path::Path, process::Command};

use crate::{
    cli::Args,
    mount::{Kind, Mount, find_symlinks},
    tools,
};

const HOME_FILES: &str = "/etc/hm-package/home-files";

fn ensure_env(key: &str) -> String {
    match std::env::var(key) {
        Ok(value) => value,
        Err(_) => {
            eprintln!("Env var {key} is required but was not set");
            std::process::exit(1);
        }
    }
}

pub fn run(args: &Args, volumes: Vec<Mount>, serve_socket: Option<&Path>) -> i32 {
    // home-manager's generated files are mapped in one by one, so the box sees the
    // same dotfiles without sharing the real home directory.
    let mut mounts: Vec<Mount> = find_symlinks(Path::new(HOME_FILES))
        .into_iter()
        .filter_map(|path| {
            let relative = path.strip_prefix(HOME_FILES).ok()?;
            Some(
                Mount::new(
                    &path,
                    format!("/home/sprrw/{}", relative.display()),
                    Kind::File,
                )
                .read_only(),
            )
        })
        .collect();

    mounts.extend(volumes);

    let cwd = std::env::current_dir().expect("Failed to get current directory");

    if args.cwd {
        mounts.push(Mount::new(&cwd, "/pwd", Kind::Dir));
    }
    if args.ro_cwd {
        mounts.push(Mount::new(&cwd, "/pwd", Kind::Dir).read_only());
    }
    if args.ro_git && cwd.join(".git").exists() {
        mounts.push(Mount::new(cwd.join(".git"), "/pwd/.git", Kind::Dir).read_only());
    }

    if let Some(socket) = serve_socket {
        // The agent runs inside the box and binds the socket itself, so the
        // directory holding it has to be visible in there at the same path. This
        // bind is emitted after --tmpfs /tmp, so a socket under /tmp survives
        // rather than being hidden by the tmpfs -- do not reorder.
        let parent = socket.parent().expect("socket path has no parent");
        mounts.push(Mount::new(parent, parent.display().to_string(), Kind::Dir));
    }

    if args.wayland {
        let socket = format!(
            "{}/{}",
            ensure_env("XDG_RUNTIME_DIR"),
            ensure_env("WAYLAND_DISPLAY")
        );
        mounts.push(Mount::new(socket, "/tmp/wayland-1", Kind::File).read_only());
    }
    if args.x11 {
        mounts.push(Mount::new("/tmp/.X11-unix", "/tmp/.X11-unix", Kind::Dir).read_only());
    }

    for (host, boxed) in [
        ("/bin", "/bin"),
        ("/etc", "/etc"),
        ("/usr", "/usr"),
        ("/lib64", "/lib64"),
        ("/run/current-system/sw", "/run/current-system/sw"),
        ("/home/sprrw/nixos", "/home/sprrw/nixos"),
    ] {
        mounts.push(Mount::new(host, boxed, Kind::Dir).read_only());
    }

    let mut envvars: Vec<String> = args.env_vars.clone();
    let inherited_path = if args.reset_env {
        String::new()
    } else {
        format!("{}:", ensure_env("PATH"))
    };
    envvars.extend([
        format!("PATH={inherited_path}/etc/hm-package/home-path/bin:/run/current-system/sw/bin"),
        "__ETC_PROFILE_SOURCED=1".to_string(),
        "IN_SPRRW_SANDBOX=1".to_string(),
        "HOME=/home/sprrw".to_string(),
        format!("EDITOR={}", ensure_env("EDITOR")),
        format!("NIX_PATH={}", ensure_env("NIX_PATH")),
        "COLORTERM=truecolor".to_string(),
        "TEMPDIR=/tmp".to_string(),
        "TMPDIR=/tmp".to_string(),
        "TEMP=/tmp".to_string(),
        "TMP=/tmp".to_string(),
    ]);

    if args.downgrade_term {
        envvars.push("TERM=xterm-256color".to_string());
    } else {
        envvars.push(format!("TERM={}", ensure_env("TERM")));
    }

    if args.wayland {
        envvars.extend([
            "WAYLAND_DISPLAY=wayland-1".to_string(),
            "XDG_RUNTIME_DIR=/tmp".to_string(),
            format!("GTK_THEME={}", ensure_env("GTK_THEME")),
        ]);
    }
    if args.x11 {
        envvars.push(format!("DISPLAY={}", ensure_env("DISPLAY")));
    }

    let exec: Vec<String> = match serve_socket {
        Some(socket) => vec![
            tools::own_executable().display().to_string(),
            "--serve-agent".to_string(),
            socket.display().to_string(),
        ],
        None if args.exec.is_empty() => vec!["bash".to_string()],
        None => args.exec.clone(),
    };

    let mut command = Command::new("bwrap");
    command.arg("--unshare-all");

    // --as-pid-1 suppresses bwrap's own PID 1 reaper. The interactive case wants
    // that, but the long-lived server does not: commands can leave orphans
    // behind, and without a reaper they would accumulate as zombies for the
    // lifetime of the session.
    if serve_socket.is_none() {
        command.arg("--as-pid-1");
    }

    command.args([
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
    ]);

    if !args.no_network {
        command.arg("--share-net");
    }

    command.args(["--chdir", args.box_cwd()]);

    for mount in &mounts {
        command.args(mount.to_bwrap_args());
    }

    command.arg("/usr/bin/env").args(&envvars).args(&exec);

    if args.reset_env {
        command.env_clear();
    }

    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(e) => {
            eprintln!("Failed to start bwrap: {e}");
            return 1;
        }
    };

    // SIGINT was already delivered to the child by the terminal, so just wait for
    // it to exit and report its status.
    match child.wait() {
        Ok(status) => status.code().unwrap_or(1),
        Err(e) => {
            eprintln!("{e}");
            let _ = child.kill();
            1
        }
    }
}

/// Re-exec the requested command directly, for when we are already inside a box.
pub fn passthrough(exec: &[String]) -> i32 {
    let (program, rest) = match exec.split_first() {
        Some(split) => split,
        None => return 0,
    };
    match Command::new(program).args(rest).status() {
        Ok(status) => status.code().unwrap_or(1),
        Err(e) => {
            eprintln!("{e}");
            1
        }
    }
}
