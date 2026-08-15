use std::path::Path;
use std::process::Command;

use crate::Cli;
use crate::common::{cwd, exit_code, find_symlinks};
use crate::mount::{BOX_CWD, Mount, MountType};

fn get_nix_argument(argname: &str) -> String {
    std::env::var(argname).expect(&format!(
        "failed to set mandatory Nix supplied arg {}",
        argname
    ))
}

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let mut mounts: Vec<Mount> = if let Ok(hm_files_path) = std::env::var("SPRRW_HOME_FILES") {
        find_symlinks(Path::new(&hm_files_path))
            .iter()
            .map(|f| {
                let relative = f.strip_prefix(&format!("{}/", hm_files_path)).unwrap_or(f);
                Mount::new(f, &format!("/home/sprrw/{relative}"), MountType::File, true)
            })
            .collect()
    } else {
        vec![]
    };
    let mut envvars: Vec<String> = args.env_vars.clone();

    mounts.extend(volume_mounts);

    if args.cwd {
        mounts.push(Mount::new(&cwd(), BOX_CWD, MountType::Dir, false));
    } else if args.ro_cwd {
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

    if args.wayland
        && let Ok(xdg_runtime_dir) = std::env::var("XDG_RUNTIME_DIR")
        && let Ok(wl_display) = std::env::var("WAYLAND_DISPLAY")
    {
        mounts.push(Mount::new(
            &format!("{}/{}", xdg_runtime_dir, wl_display),
            "/tmp/wayland-1",
            MountType::File,
            true,
        ));
        envvars.extend([
            "WAYLAND_DISPLAY=wayland-1".to_string(),
            "XDG_RUNTIME_DIR=/tmp".to_string(),
        ]);

        if let Ok(gtk_theme) = std::env::var("GTK_THEME") {
            envvars.push(format!("GTK_THEME={}", gtk_theme));
        }
    }

    if args.x11
        && let Ok(display) = std::env::var("DISPLAY")
    {
        mounts.push(Mount::new(
            "/tmp/.X11-unix",
            "/tmp/.X11-unix",
            MountType::Dir,
            true,
        ));
        envvars.push(format!("DISPLAY={}", display));
    }

    mounts.extend([
        Mount::new(&get_nix_argument("SPRRW_BIN"), "/bin", MountType::Dir, true),
        Mount::new(&get_nix_argument("SPRRW_ETC"), "/etc", MountType::Dir, true),
        Mount::new(&get_nix_argument("SPRRW_USR"), "/usr", MountType::Dir, true),
        Mount::new(
            &get_nix_argument("SPRRW_LIB64"),
            "/lib64",
            MountType::Dir,
            true,
        ),
    ]);

    envvars.extend(
        [
            format!(
                "PATH={}",
                format!(
                    "{}:{}",
                    if !args.reset_env
                        && let Ok(path) = std::env::var("PATH")
                    {
                        path
                    } else {
                        "".to_string()
                    },
                    if let Ok(sprrw_path) = std::env::var("SPRRW_PATH") {
                        sprrw_path
                    } else {
                        "".to_string()
                    }
                )
                .trim_matches(':')
            ),
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

    envvars.push(format!(
        "TERM={}",
        if !args.downgrade_term
            && let Ok(term) = std::env::var("TERM")
        {
            term
        } else {
            "xterm-256color".to_string()
        }
    ));

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

    if cfg!(target_os = "linux") {
        // Ignore SIGINT (it will be handled by child)
        unsafe { libc::signal(libc::SIGINT, libc::SIG_IGN) };
        // TODO: Should this exist on Mac too
    }

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
