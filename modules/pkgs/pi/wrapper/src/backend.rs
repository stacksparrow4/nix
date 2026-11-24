use std::{
    env,
    path::Path,
    process::{Child, Command, Stdio},
    thread::sleep,
    time::Duration,
};

use tempfile::{TempDir, tempdir};

use crate::{
    plan::{Plan, Target},
    remote::{INTERNAL_SERVE_ENV, SOCKET_NAME, start_remote_server},
    vm::Vm,
    volumes::{self, VolAccess, VolType, volume},
};

pub const BRIDGE_DIR: &str = "/tmp/pi-remote";

pub enum Backend {
    Sandbox(ToolSandbox),
    Vm { _vm: Vm, server: TempDir },
    Remote { server: TempDir },
}

impl Backend {
    pub fn start(plan: &Plan, sandbox_args: &[String]) -> Result<Backend, String> {
        Ok(match &plan.target {
            Target::Sandbox => {
                Backend::Sandbox(ToolSandbox::start(sandbox_args, plan.local.is_some())?)
            }
            Target::Vm => {
                let vm = Vm::start(sandbox_args, plan.cwd.is_some())?;
                let server = start_remote_server(vm.template())?;
                Backend::Vm { _vm: vm, server }
            }
            Target::Remote(template) => Backend::Remote {
                server: start_remote_server(template)?,
            },
        })
    }

    pub fn bridge_dir(&self) -> &Path {
        match self {
            Backend::Sandbox(sandbox) => sandbox.dir.path(),
            Backend::Vm { server, .. } | Backend::Remote { server } => server.path(),
        }
    }
}

pub struct ToolSandbox {
    dir: TempDir,
    proc: Child,
}

impl ToolSandbox {
    fn start(sandbox_args: &[String], no_network: bool) -> Result<ToolSandbox, String> {
        let dir = tempdir().expect("Failed to create temporary bridge dir");

        let mut cmd = Command::new("box");
        cmd.arg("--docker").args(volume(
            dir.path().display(),
            BRIDGE_DIR,
            VolAccess::Rw,
            VolType::Dir,
        ));
        if no_network {
            cmd.arg("--no-network");
        }
        cmd.args(sandbox_args);
        cmd.args(volumes::env(
            INTERNAL_SERVE_ENV,
            format!("{BRIDGE_DIR}/{SOCKET_NAME}"),
        ));

        let bin = env::var("SPRRW_SUBAGENT_BIN").unwrap();
        let path = match env::var("SPRRW_ADDITIONAL_PATH") {
            Ok(existing) => format!("{bin}:{existing}"),
            Err(_) => bin,
        };
        cmd.env("SPRRW_ADDITIONAL_PATH", path);

        let proc = cmd
            .arg("--")
            .arg(env::var("SPRRW_PI_WRAPPER_LINUX").unwrap())
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .spawn()
            .map_err(|e| format!("Failed to start tool sandbox: {e}"))?;

        let mut sandbox = ToolSandbox { dir, proc };
        let socket = sandbox.dir.path().join(SOCKET_NAME);

        while !socket.exists() {
            if let Some(status) = sandbox
                .proc
                .try_wait()
                .map_err(|e| format!("Failed to poll the tool sandbox process: {e}"))?
            {
                return Err(format!(
                    "Tool sandbox exited before it was ready ({status})"
                ));
            }

            sleep(Duration::from_millis(25));
        }

        Ok(sandbox)
    }
}

impl Drop for ToolSandbox {
    fn drop(&mut self) {
        unsafe { libc::kill(self.proc.id() as i32, libc::SIGTERM) };
        let _ = self.proc.wait();
    }
}
