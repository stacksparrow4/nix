use std::io::Write;
use std::process::{Command, Stdio};

use crate::Cli;
use crate::common::exit_code;
use crate::container::get_container_args;
use crate::mount::Mount;

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let container_args = get_container_args(args, volume_mounts);

    let mut docker_build = Command::new("docker")
        .args(["build", "-f", "-", "-t", "sprrw-sandbox"])
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("failed to spawn docker process");

    docker_build
        .stdin
        .take()
        .unwrap()
        // TODO: should this match uid/gid
        .write_all(b"FROM alpine\nRUN adduser -s /bin/sh -G users -u 1000 -D sprrw\nUSER sprrw")
        .expect("failed to write data to docker build");
    docker_build.wait().expect("docker build failed");

    let mut docker_args: Vec<String> = ["--rm", "-it", "-v", "/nix/store:/nix/store:ro"]
        .iter()
        .map(|a| a.to_string())
        .collect();

    if Command::new("docker")
        .arg("version")
        .output()
        .map(|out| {
            String::from_utf8_lossy(&out.stdout)
                .to_lowercase()
                .contains("podman")
        })
        .unwrap_or(false)
    {
        docker_args.push("--userns=keep-id".to_string());
    }

    if args.no_network {
        docker_args.extend(["--network".to_string(), "none".to_string()]);
    }

    docker_args.push("-w".to_string());
    docker_args.push(container_args.workdir);

    for m in container_args.mounts.iter() {
        docker_args.extend(m.to_docker_args());
    }

    for e in container_args.envvars.iter() {
        docker_args.extend(["-e".to_string(), e.to_string()]);
    }

    docker_args.push("sprrw-sandbox".to_string());
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
