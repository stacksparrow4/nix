mod bwrap;
mod cli;
mod mount;
mod proxy;
mod tools;
mod vm;

use std::{
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};

use clap::Parser;

use cli::{Args, Backend};

/// Only installed when serving: in an interactive session Ctrl-C belongs to the
/// program running inside the box.
pub fn install_shutdown_handler(vm: Arc<Mutex<vm::Vm>>) {
    use signal_hook::{consts::TERM_SIGNALS, iterator::Signals};

    let mut signals = match Signals::new(TERM_SIGNALS) {
        Ok(signals) => signals,
        Err(e) => {
            eprintln!("Could not install signal handlers: {e}");
            return;
        }
    };

    std::thread::spawn(move || {
        if signals.forever().next().is_some() {
            vm.lock().unwrap().shut_down();
            std::process::exit(143);
        }
    });
}

fn fail(message: impl std::fmt::Display) -> ! {
    eprintln!("{message}");
    std::process::exit(1);
}

fn main() {
    let args = Args::parse();

    if let Some(socket) = args.serve_agent.as_deref() {
        if let Err(e) = bridge::serve(Path::new(socket), bridge::Local) {
            fail(format!("Failed to serve on {socket}: {e}"));
        }
        return;
    }

    if let Some(socket) = args.proxy.as_deref() {
        std::process::exit(proxy::run(Path::new(socket)));
    }

    if args.ro_git && !args.cwd {
        fail("Cannot specify --ro-git without --cwd");
    }
    if args.cwd && args.ro_cwd {
        fail("Cannot specify --ro-cwd with --cwd");
    }

    let serve_socket: Option<PathBuf> = match args.serve.as_deref() {
        Some(path) => {
            if !args.exec.is_empty() {
                fail("Cannot specify a command with --serve");
            }
            if args.backend() == Backend::Podman {
                fail("--serve is not supported by the podman backend");
            }
            if args.vm_console {
                fail("Cannot specify --vm-console with --serve");
            }
            let path = PathBuf::from(path);
            if let Err(problem) = bridge::validate_socket_path(&path) {
                fail(format!("--serve socket path {problem}"));
            }
            Some(path)
        }
        None => None,
    };

    if std::env::var_os("IN_SPRRW_SANDBOX").is_some() {
        let exec = if args.exec.is_empty() {
            vec!["bash".to_string()]
        } else {
            args.exec.clone()
        };
        std::process::exit(bwrap::passthrough(&exec));
    }

    let mut volumes = Vec::new();
    for spec in &args.volumes {
        match mount::parse_volume(spec) {
            Ok(mount) => volumes.push(mount),
            Err(problem) => fail(problem),
        }
    }
    for volume in &volumes {
        if let Err(problem) = volume.ensure_exists() {
            fail(problem);
        }
    }

    let code = match args.backend() {
        Backend::Bwrap => bwrap::run(&args, volumes, serve_socket.as_deref()),
        Backend::Vm => vm::run(&args, volumes, serve_socket.as_deref()),
        Backend::Podman => fail("The podman backend is not implemented"),
    };

    std::process::exit(code);
}
