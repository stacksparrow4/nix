use std::path::Path;
use std::process::Command;

use crate::Cli;
use crate::common::{exit_code, get_nix_argument};
use crate::container::get_container_args;
use crate::mount::{BOX_HOME, Mount, MountType};

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let mut container_args = get_container_args(args, volume_mounts, vec![]);

    container_args.mounts.extend([
        Mount::new(&get_nix_argument("SPRRW_BIN"), "/bin", MountType::Dir, true),
        Mount::new(&get_nix_argument("SPRRW_ETC"), "/etc", MountType::Dir, true),
        Mount::new(&get_nix_argument("SPRRW_USR"), "/usr", MountType::Dir, true),
    ]);

    if Path::new("/etc/resolv.conf").exists() {
        container_args.mounts.push(Mount::new(
            "/etc/resolv.conf",
            "/etc/resolv.conf",
            MountType::File,
            true,
        ));
    }
    if Path::new("/etc/fonts").exists() {
        container_args
            .mounts
            .push(Mount::new("/etc/fonts", "/etc/fonts", MountType::Dir, true));
    }

    container_args.envvars.push("USER=root".to_string());

    let mut subprocess_args: Vec<String> = [
        "--unshare-all",
        "--as-pid-1",
        "--die-with-parent",
        "--uid",
        "0",
        "--gid",
        "0",
        "--tmpfs",
        "/tmp",
        "--proc",
        "/proc",
        "--dev",
        "/dev",
        "--dir",
        BOX_HOME,
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
    subprocess_args.push(container_args.workdir);

    for m in container_args.mounts.iter() {
        subprocess_args.extend(m.to_bwrap_args());
    }

    subprocess_args.push("/usr/bin/env".to_string());
    subprocess_args.extend(container_args.envvars);
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

    // Ignore SIGINT (it will be handled by child)
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
