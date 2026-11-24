use std::process::{Child, Command, Stdio};

use tempfile::{TempDir, tempdir};

use crate::volumes::{VolAccess, VolType, volume};

pub const SHELL_PREFIX: &str =
    "socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama/llama.sock &>/dev/null & ";
const GUEST_DIR: &str = "/tmp/llama";

pub struct LocalNet {
    dir: TempDir,
    proc: Child,
}

impl LocalNet {
    pub fn start(target: &str) -> Result<LocalNet, String> {
        let dir = tempdir().expect("Failed to create temporary socat dir");

        let proc = Command::new("socat")
            .arg(format!("UNIX-LISTEN:{}/llama.sock,fork", dir.path().display()))
            .arg(target)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("Failed to start socat: {e}"))?;

        Ok(LocalNet { dir, proc })
    }

    pub fn box_args(&self) -> Vec<String> {
        let mut args = vec!["--no-network".to_string()];
        args.extend(volume(
            self.dir.path().display(),
            GUEST_DIR,
            VolAccess::Ro,
            VolType::Dir,
        ));
        args
    }
}

impl Drop for LocalNet {
    fn drop(&mut self) {
        let _ = self.proc.kill();
        let _ = self.proc.wait();
    }
}
