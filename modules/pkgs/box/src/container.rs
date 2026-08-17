use std::path::Path;

use crate::{
    common::{Cli, cwd, find_symlinks},
    mount::{BOX_CWD, Mount, MountType},
};

pub struct ContainerArgs {
    pub mounts: Vec<Mount>,
    pub envvars: Vec<String>,
    pub workdir: String,
}

fn get_nix_argument(argname: &str) -> String {
    std::env::var(argname)
        .unwrap_or_else(|_| panic!("failed to set mandatory Nix supplied arg {}", argname))
}

pub fn get_container_args(args: &Cli, volume_mounts: Vec<Mount>) -> ContainerArgs {
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

    mounts.extend([
        Mount::new(&get_nix_argument("SPRRW_BIN"), "/bin", MountType::Dir, true),
        Mount::new(&get_nix_argument("SPRRW_ETC"), "/etc", MountType::Dir, true),
        Mount::new(&get_nix_argument("SPRRW_USR"), "/usr", MountType::Dir, true),
        // TODO: Make nix-ld work inside the box and fix this
        // Mount::new(
        //     &get_nix_argument("SPRRW_LIB64"),
        //     "/lib64",
        //     MountType::Dir,
        //     true,
        // ),
    ]);

    if Path::new("/etc/resolv.conf").exists() {
        mounts.push(Mount::new("/etc/resolv.conf", "/etc/resolv.conf", MountType::File, true));
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
                    .collect::<Vec<String>>()
                    .join(":")
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
        "/home/sprrw"
    };

    ContainerArgs {
        mounts,
        envvars,
        workdir: cwd.to_string(),
    }
}
