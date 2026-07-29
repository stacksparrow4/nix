//! Store paths are baked in at build time (see default.nix) rather than prefixed
//! onto PATH, so sandboxes do not inherit these tools. qemu is looked up on PATH
//! instead, to keep its ~1GB closure out of ours.

use std::path::{Path, PathBuf};

fn from_path(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    std::env::split_paths(&path)
        .map(|dir| dir.join(name))
        .find(|candidate| is_executable(candidate))
}

fn is_executable(path: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    path.metadata()
        .is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
}

fn resolve(baked: Option<&str>, name: &str) -> PathBuf {
    if let Some(baked) = baked {
        return PathBuf::from(baked);
    }
    match from_path(name) {
        Some(found) => found,
        None => {
            eprintln!("Required program {name} was not found on PATH");
            std::process::exit(1);
        }
    }
}

pub fn ssh() -> PathBuf {
    resolve(option_env!("SANDBOX_SSH"), "ssh")
}

pub fn ssh_keygen() -> PathBuf {
    resolve(option_env!("SANDBOX_SSH_KEYGEN"), "ssh-keygen")
}

pub fn qemu() -> PathBuf {
    resolve(None, "qemu-system-x86_64")
}

/// The store is bind-mounted into the sandbox, so this path resolves in both.
pub fn own_executable() -> PathBuf {
    match std::env::current_exe() {
        Ok(path) => path,
        Err(e) => {
            eprintln!("Could not determine the path to this program: {e}");
            std::process::exit(1);
        }
    }
}
