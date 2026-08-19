mod bwrap;
mod mount;
mod common;
mod vm;
mod docker;
mod container;

use std::path::Path;
use std::process::Command;

use clap::Parser;
use mount::{Mount, MountType};
use common::exit_code;

use crate::common::Cli;

fn main() {
    let mut args = Cli::parse();

    if args.ro_git && !args.cwd {
        println!("Cannot specify --ro-git without --cwd");
        std::process::exit(1);
    }

    if args.cwd && args.ro_cwd {
        println!("Cannot specify --ro-cwd with --cwd");
        std::process::exit(1);
    }

    if args.exec.is_empty() {
        args.exec = vec!["bash".to_string()];
    }
    
    if std::env::var("IN_SPRRW_SANDBOX").is_ok() {
        let status = Command::new(&args.exec[0])
            .args(&args.exec[1..])
            .status()
            .unwrap_or_else(|err| {
                eprintln!("{err}");
                std::process::exit(1);
            });
        std::process::exit(exit_code(&status));
    }

    let volume_mounts: Vec<Mount> = args.volumes.iter().map(|v| {
        let components: Vec<&str> = v.split(':').collect();

        Mount {
            host_path: components[0].to_string(),
            box_path: components[1].to_string(),
            mount_type: if let Some(mount_type) = components.get(3) {
                MountType::parse(mount_type).expect("invalid type for the mount {v} : {mount_type}")
            } else {
                MountType::Unknown
            },
            ro: if components.len() >= 3 {
                match components[2] {
                    "ro" => true,
                    "rw" => false,
                    other => panic!("the mount {v} has invalid type {other}"),
                }
            } else if components.len() == 2 {
                false
            } else {
                panic!(
                "the mount {v} is missing a box path, expected the form hostpath:boxpath:ro/rw:type"
                );
            },
        }
    }).collect();

    for v in volume_mounts.iter() {
        if Path::new(&v.host_path).exists() {
            continue;
        }

        match v.mount_type {
            MountType::Unknown => {
                panic!(
                    "The mount {} did not exist on the host and no type was specified to autocreate with",
                    v.host_path
                );
            }
            MountType::Dir => std::fs::create_dir_all(&v.host_path)
                .unwrap_or_else(|err| panic!("failed to create {}: {err}", v.host_path)),
            MountType::File => {
                if let Some(parent) = Path::new(&v.host_path).parent() {
                    std::fs::create_dir_all(parent).unwrap_or_else(|err| {
                        panic!("failed to create directory {:?}: {err}", parent)
                    });
                }
                let _ = std::fs::OpenOptions::new()
                    .append(true)
                    .create(true)
                    .open(&v.host_path)
                    .unwrap_or_else(|err| {
                        panic!("failed to initialise file {}: {}", v.host_path, err)
                    });
            }
        }
    }

    let run = match (cfg!(target_os = "linux"), args.vm, args.docker) {
        (true, false, false) => bwrap::run,
        (true, true, false) => vm::run,
        (_, false, _) => docker::run,
        _ => panic!("invalid backends supplied"),
    };

    run(&args, volume_mounts);
}
