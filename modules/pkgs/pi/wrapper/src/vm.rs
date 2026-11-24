use std::{
    io::{self, BufRead, BufReader, Write},
    process::{Child, Command, Stdio},
    thread::{self, sleep},
    time::{Duration, Instant},
};

use crate::remote::CMD_PLACEHOLDER;

const PORT_PREFIX: &str = "Forwarding SSH to port ";
const SSH_READY_TIMEOUT: Duration = Duration::from_secs(120);
const SSH_PASSWORD: &str = "password";
const SSH_OPTS: &[&str] = &[
    "-o",
    "StrictHostKeyChecking=no",
    "-o",
    "UserKnownHostsFile=/dev/null",
    "-o",
    "LogLevel=ERROR",
];

pub struct Vm {
    proc: Child,
    template: String,
}

impl Vm {
    pub fn start(sandbox_args: &[String], share_cwd: bool) -> Result<Vm, String> {
        let proc = Command::new("box")
            .arg("--vm")
            .args(sandbox_args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("Failed to start VM box: {e}"))?;

        let mut vm = Vm {
            proc,
            template: String::new(),
        };

        let port = vm.read_ssh_port()?;

        let starter = if share_cwd { "'cd ~/box &&' " } else { "" };
        vm.template = format!(
            "sshpass {} localhost 'exec 0</dev/null;' {starter}{CMD_PLACEHOLDER}",
            ssh_args(port).join(" ")
        );

        let ready_check = if share_cwd {
            "mountpoint -q ~/box"
        } else {
            "true"
        };
        vm.wait_for_ssh(port, ready_check)?;

        Ok(vm)
    }

    pub fn template(&self) -> &str {
        &self.template
    }

    fn read_ssh_port(&mut self) -> Result<u16, String> {
        let stdout = self.proc.stdout.take().expect("VM stdout is piped");
        let mut reader = BufReader::new(stdout);

        let mut line = String::new();
        reader
            .read_line(&mut line)
            .map_err(|e| format!("Failed to read from VM process: {e}"))?;

        let port = line
            .trim()
            .strip_prefix(PORT_PREFIX)
            .and_then(|p| p.parse().ok())
            .ok_or_else(|| format!("Failed to extract SSH port from VM output: {}", line.trim()))?;

        thread::spawn(move || {
            let _ = io::copy(&mut reader, &mut io::sink());
        });

        Ok(port)
    }

    fn wait_for_ssh(&mut self, port: u16, ready_check: &str) -> Result<(), String> {
        let start = Instant::now();

        loop {
            if let Some(status) = self
                .proc
                .try_wait()
                .map_err(|e| format!("Failed to poll the VM process: {e}"))?
            {
                return Err(format!("VM exited before SSH was ready ({status})"));
            }

            let ready = Command::new("sshpass")
                .args(ssh_args(port))
                .args(["-o", "ConnectTimeout=2", "localhost", ready_check])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .is_ok_and(|s| s.success());

            if ready {
                return Ok(());
            }

            if start.elapsed() >= SSH_READY_TIMEOUT {
                return Err(format!("Timed out waiting for VM SSH on port {port}"));
            }

            sleep(Duration::from_millis(250));
        }
    }
}

impl Drop for Vm {
    fn drop(&mut self) {
        if let Some(stdin) = self.proc.stdin.as_mut() {
            let _ = stdin.write_all(b"exit\n");
        }
        let _ = self.proc.wait();
    }
}

fn ssh_args(port: u16) -> Vec<String> {
    ["-p", SSH_PASSWORD, "ssh", "-n"]
        .into_iter()
        .chain(SSH_OPTS.iter().copied())
        .map(String::from)
        .chain(["-p".to_string(), port.to_string()])
        .collect()
}
