use std::process::Command;

use crate::Cli;
use crate::common::exit_code;
use crate::container::get_container_args;
use crate::mount::Mount;

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let container_args = get_container_args(args, volume_mounts);

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
        container_args.workdir
    );

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
