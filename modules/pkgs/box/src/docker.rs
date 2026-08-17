use std::process::Command;

use crate::Cli;
use crate::common::exit_code;
use crate::container::get_container_args;
use crate::mount::Mount;

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let container_args = get_container_args(args, volume_mounts);
    
    // TODO: Create docker image if not exist (feed from stdin)

    let mut docker_args: Vec<String> = [
        "--rm",
        "-it",
        "-v",
        "/nix/store:/nix/store:ro",
    ]
    .iter()
    .map(|a| a.to_string())
    .collect();

    if args.no_network {
        docker_args.extend(["--network".to_string(), "none".to_string()]);
    }

    docker_args.push("-w".to_string());
    docker_args.push(
        container_args.workdir
    );

    for m in container_args.mounts.iter() {
        docker_args.extend(m.to_docker_args());
    }

    for e in container_args.envvars.iter() {
        docker_args.extend(["-e".to_string(), e.to_string()]);
    }

    // TODO: add image
    docker_args.extend(args.exec.clone());

    let mut command = Command::new("docker");
    command.arg("run");
    command.args(&docker_args);
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
