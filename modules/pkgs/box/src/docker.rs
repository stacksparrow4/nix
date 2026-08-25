use std::io::IsTerminal;
use std::process::Command;
use std::thread;

use libc::SIGTERM;
use rand::distr::{Alphanumeric, SampleString};
use signal_hook::iterator::Signals;

use crate::Cli;
use crate::common::exit_code;
use crate::container::get_container_args;
use crate::mount::Mount;

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    let container_args = get_container_args(
        args,
        volume_mounts,
        [
            "/usr/local/sbin",
            "/usr/local/bin",
            "/usr/sbin",
            "/usr/bin",
            "/sbin",
            "/bin",
        ]
        .into_iter()
        .map(|x| x.to_string())
        .collect(),
    );

    let mut docker_args: Vec<String> = ["--rm", "-i", "-v", "/nix/store:/nix/store:ro"]
        .iter()
        .map(|a| a.to_string())
        .collect();

    let container_name = Alphanumeric.sample_string(&mut rand::rng(), 8);
    docker_args.extend(["--name".to_string(), container_name.clone()]);

    if std::io::stdin().is_terminal() {
        docker_args.push("-t".to_string());
    }

    docker_args.extend([
        "--network".to_string(),
        if args.no_network { "none" } else { "host" }.to_string(),
    ]);

    docker_args.push("-w".to_string());
    docker_args.push(container_args.workdir);

    for m in container_args.mounts.iter() {
        docker_args.extend(m.to_docker_args());
    }

    for e in container_args.envvars.iter() {
        docker_args.extend(["-e".to_string(), e.to_string()]);
    }

    docker_args.push("alpine:latest".to_string());
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

    thread::spawn(move || {
        let mut signals = Signals::new([SIGTERM]).unwrap();

        for _ in signals.forever() {
            Command::new("docker")
                .arg("kill")
                .arg(&container_name)
                .spawn()
                .expect("failed to run docker kill")
                .wait()
                .expect("failed to wait on docker kill");
        }
    });

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
