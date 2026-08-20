use std::{fs, path::Path};

use crate::{
    common::{Cli, cwd, find_symlinks, get_nix_argument},
    mount::{BOX_CWD, BOX_HOME, Mount, MountType},
};

pub struct ContainerArgs {
    pub mounts: Vec<Mount>,
    pub envvars: Vec<String>,
    pub workdir: String,
}

pub fn get_container_args(
    args: &Cli,
    volume_mounts: Vec<Mount>,
    extra_path: Vec<String>,
) -> ContainerArgs {
    let mut mounts: Vec<Mount> = if let Ok(hm_files_path) = std::env::var("SPRRW_HOME_FILES") {
        find_symlinks(Path::new(&hm_files_path))
            .iter()
            .map(|f| {
                let relative = f.strip_prefix(&format!("{}/", hm_files_path)).unwrap_or(f);
                Mount::new(f, &format!("{}/{}", BOX_HOME, relative), MountType::File, true)
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
            &format!("{}/.git", BOX_CWD),
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

    envvars.extend(
        [
            format!(
                "PATH={}",
                std::iter::empty()
                    .chain(
                        if !args.reset_env
                            && let Ok(path) = std::env::var("PATH")
                        {
                            Some(path)
                        } else {
                            None
                        }
                    )
                    .chain(std::env::var("SPRRW_PATH").ok())
                    .chain(std::env::var("SPRRW_ADDITIONAL_PATH").ok())
                    .chain(
                        fs::read_link("/etc/static/hm-package")
                            .ok()
                            .map(|pb| format!("{}/home-path/bin", pb.to_string_lossy()))
                    )
                    .chain(
                        fs::read_link("/run/current-system/sw")
                            .ok()
                            .map(|pb| format!("{}/bin", pb.to_string_lossy()))
                    )
                    .chain(extra_path)
                    .collect::<Vec<String>>()
                    .join(":")
            ),
            "IN_SPRRW_SANDBOX=1".to_string(),
            format!("HOME={}", BOX_HOME),
            "COLORTERM=truecolor".to_string(),
            "TEMPDIR=/tmp".to_string(),
            "TMPDIR=/tmp".to_string(),
            "TEMP=/tmp".to_string(),
            "TMP=/tmp".to_string(),
            "SHELL=/bin/sh".to_string(), // TODO: should this be bash?
        ]
        .into_iter()
        .chain(std::env::var("EDITOR").map(|e| format!("EDITOR={}", e)))
        .chain(std::env::var("NIX_PATH").map(|np| format!("NIX_PATH={}", np))),
    );

    envvars.extend(
        if !args.downgrade_term
            && let Ok(term) = std::env::var("TERM")
        {
            vec![
                format!("TERM={}", term),
                format!("TERMINFO={}", get_nix_argument("SPRRW_TERMINFO")),
                format!("TERMINFO_DIRS={}", get_nix_argument("SPRRW_TERMINFO")),
            ]
        } else {
            vec!["TERM=xterm-256color".to_string()]
        },
    );

    let cwd = if args.cwd || args.ro_cwd {
        BOX_CWD
    } else {
        BOX_HOME
    };

    ContainerArgs {
        mounts,
        envvars,
        workdir: cwd.to_string(),
    }
}
