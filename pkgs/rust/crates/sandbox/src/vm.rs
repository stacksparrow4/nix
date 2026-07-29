use std::{
    fs,
    io::Write,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use base64::prelude::*;

use crate::{
    cli::Args,
    mount::{Kind, Mount},
    tools,
};

/// Arbitrary: the VM is reached through a socket, so this only keys known_hosts.
const SSH_HOST: &str = "sandbox-vm";

/// Torn down however we exit, including on SIGTERM.
pub struct Vm {
    rundir: PathBuf,
    qemu_pid: Option<i32>,
    ssh_base: Vec<String>,
    keep_rundir: bool,
}

impl Vm {
    fn console_log(&self) -> PathBuf {
        self.rundir.join("console.log")
    }

    pub fn shut_down(&mut self) {
        eprintln!("Terminating qemu...");

        if !self.ssh_base.is_empty() {
            let (program, options) = self.ssh_base.split_first().unwrap();
            let _ = Command::new(program)
                .args(options)
                .args(["-O", "exit"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status();
        }

        if let Some(pid) = self.qemu_pid.take() {
            unsafe {
                libc::kill(pid, libc::SIGTERM);
            }
        }

        if self.keep_rundir {
            eprintln!("Kept VM state for debugging in {}", self.rundir.display());
            eprintln!("  full boot log: {}", self.console_log().display());
            eprintln!("  for an interactive serial console, re-run with --vm-console");
            eprintln!("  rm -rf {}   # when done", self.rundir.display());
        } else {
            let _ = fs::remove_dir_all(&self.rundir);
        }
    }
}

/// Private directory for the control socket and credentials.
///
/// The path must contain no hyphen: QEMU <= 10.2 splits a `hostfwd=unix:<path>-:22`
/// rule at the first hyphen, not the last, and rejects it as "Bad guest address".
fn make_rundir() -> PathBuf {
    let mut bases: Vec<PathBuf> = Vec::new();
    if let Some(dir) = std::env::var_os("XDG_RUNTIME_DIR") {
        bases.push(PathBuf::from(dir));
    }
    bases.push(std::env::temp_dir());
    bases.push(PathBuf::from("/tmp"));

    for base in bases {
        if !base.is_dir() || base.display().to_string().contains('-') {
            continue;
        }
        if let Ok(dir) = tempfile::Builder::new()
            .prefix("sandboxvm.")
            .tempdir_in(&base)
        {
            let path = dir.keep();
            let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o700));
            return path;
        }
    }

    eprintln!(
        "Could not find a hyphen-free directory to hold the VM control socket \
         (tried $XDG_RUNTIME_DIR, $TMPDIR and /tmp)"
    );
    std::process::exit(1);
}

fn keygen(path: &Path) {
    let status = Command::new(tools::ssh_keygen())
        .args(["-q", "-t", "ed25519", "-N", "", "-C", ""])
        .arg("-f")
        .arg(path)
        .status();
    match status {
        Ok(status) if status.success() => {}
        _ => {
            eprintln!("Failed to generate an ssh key at {}", path.display());
            std::process::exit(1);
        }
    }
}

/// systemd's PID 1 exposes SMBIOS type 11 OEM strings in /run/credentials/@system.
/// Passed as a file so commas need no escaping.
fn write_credential(rundir: &Path, name: &str, data: &[u8]) -> PathBuf {
    let path = rundir.join(format!("cred.{name}"));
    let mut file = fs::File::create(&path).expect("Failed to create credential file");
    file.write_all(format!("io.systemd.credential.binary:{name}=").as_bytes())
        .and_then(|_| file.write_all(BASE64_STANDARD.encode(data).as_bytes()))
        .expect("Failed to write credential file");
    let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
    path
}

fn remote_script(lines: &[String]) -> String {
    let script = format!("{}\n", lines.join("\n"));
    let payload = BASE64_STANDARD.encode(script);
    format!(
        "printf %s {payload} | base64 -d > /tmp/startup.sh && exec bash /tmp/startup.sh",
        payload = shlex::try_quote(&payload).unwrap()
    )
}

fn pid_alive(pid: i32) -> bool {
    unsafe { libc::kill(pid, 0) == 0 || *libc::__errno_location() != libc::ESRCH }
}

fn tail(path: &Path, limit: usize) -> String {
    match fs::read_to_string(path) {
        Ok(text) if text.len() > limit => text[text.len() - limit..].to_string(),
        Ok(text) => text,
        Err(_) => format!("(could not read {})", path.display()),
    }
}

pub fn run(args: &Args, volumes: Vec<Mount>, serve_socket: Option<&Path>) -> i32 {
    for volume in &volumes {
        if volume.kind != Kind::Dir {
            eprintln!(
                "VM backend only supports directory mounts, got a non-directory for {}",
                volume.host_path.display()
            );
            return 1;
        }
    }

    let mut mounts = volumes;
    let cwd = std::env::current_dir().expect("Failed to get current directory");

    if args.cwd {
        mounts.push(Mount::new(&cwd, "/pwd", Kind::Dir));
    }
    if args.ro_cwd {
        mounts.push(Mount::new(&cwd, "/pwd", Kind::Dir).read_only());
    }
    if args.ro_git && cwd.join(".git").exists() {
        mounts.push(Mount::new(cwd.join(".git"), "/pwd/.git", Kind::Dir).read_only());
    }

    let boot_dir = match std::env::var_os("HOME") {
        Some(home) => PathBuf::from(home).join(".local/vm-boot"),
        None => {
            eprintln!("HOME is required but was not set");
            return 1;
        }
    };
    if !boot_dir.is_dir() {
        eprintln!(
            "{} does not exist. Run `build-vm` first.",
            boot_dir.display()
        );
        return 1;
    }

    let qemu = tools::qemu();
    let rundir = make_rundir();

    let ssh_sock = rundir.join("ssh.sock");
    let host_key = rundir.join("host_key");
    let client_key = rundir.join("id");
    let known_hosts = rundir.join("known_hosts");
    let pidfile = rundir.join("pid");
    let console_log = rundir.join("console.log");

    keygen(&host_key);
    keygen(&client_key);

    let host_pub =
        fs::read_to_string(rundir.join("host_key.pub")).expect("Failed to read host key");
    fs::write(&known_hosts, format!("{SSH_HOST} {}\n", host_pub.trim()))
        .expect("Failed to write known_hosts");

    let host_key_cred = write_credential(
        &rundir,
        "sandbox.host_key",
        &fs::read(&host_key).expect("Failed to read host key"),
    );
    let authorized_keys_cred = write_credential(
        &rundir,
        "sandbox.authorized_keys",
        &fs::read(rundir.join("id.pub")).expect("Failed to read client key"),
    );

    let mut netdev = format!("user,id=net0,hostfwd=unix:{}-:22", ssh_sock.display());
    if args.no_network {
        netdev.push_str(",restrict=on");
    }

    let cmdline = fs::read_to_string(boot_dir.join("cmdline")).expect("Failed to read cmdline");

    let mut qemu_args: Vec<String> = vec![
        "-nodefaults".into(),
        "-machine".into(),
        "q35,accel=kvm".into(),
        "-cpu".into(),
        "host".into(),
        "-m".into(),
        args.vm_memory.to_string(),
        "-smp".into(),
        args.vm_cpus.to_string(),
        "-kernel".into(),
        boot_dir.join("kernel").display().to_string(),
        "-initrd".into(),
        boot_dir.join("initrd").display().to_string(),
        "-append".into(),
        cmdline.trim().to_string(),
        "-drive".into(),
        format!(
            "file={},format=raw,if=none,id=iso,readonly=on",
            boot_dir.join("image.iso").display()
        ),
        "-device".into(),
        "virtio-blk-pci,drive=iso".into(),
        "-device".into(),
        "virtio-rng-pci".into(),
        "-netdev".into(),
        netdev,
        "-device".into(),
        "virtio-net-pci,netdev=net0".into(),
        "-smbios".into(),
        format!("type=11,path={}", host_key_cred.display()),
        "-smbios".into(),
        format!("type=11,path={}", authorized_keys_cred.display()),
    ];

    for (i, mount) in mounts.iter().enumerate() {
        qemu_args.push("-virtfs".into());
        qemu_args.push(format!(
            "local,path={},mount_tag=sandboxshare{i},security_model=none,id=host{i}{}",
            mount.host_path.display(),
            if mount.read_only { ",readonly=on" } else { "" }
        ));
    }

    qemu_args.extend(["-display".to_string(), "none".to_string()]);

    if args.vm_console {
        qemu_args.extend(["-serial".to_string(), "mon:stdio".to_string()]);
    } else {
        qemu_args.extend([
            "-serial".to_string(),
            format!("file:{}", console_log.display()),
            "-daemonize".to_string(),
            "-pidfile".to_string(),
            pidfile.display().to_string(),
        ]);
    }

    let ssh_base: Vec<String> = vec![
        tools::ssh().display().to_string(),
        "-F".into(),
        "/dev/null".into(),
        "-o".into(),
        "IdentitiesOnly=yes".into(),
        "-o".into(),
        format!("IdentityFile={}", client_key.display()),
        "-o".into(),
        "PreferredAuthentications=publickey".into(),
        "-o".into(),
        "StrictHostKeyChecking=yes".into(),
        "-o".into(),
        format!("UserKnownHostsFile={}", known_hosts.display()),
        "-o".into(),
        format!(
            "ProxyCommand={} --proxy {}",
            tools::own_executable().display(),
            ssh_sock.display()
        ),
        "-o".into(),
        "ControlMaster=auto".into(),
        "-o".into(),
        format!("ControlPath={}", rundir.join("cm").display()),
        "-o".into(),
        if serve_socket.is_some() {
            "ControlPersist=yes".into()
        } else {
            "ControlPersist=60".into()
        },
        "-o".into(),
        "ConnectTimeout=5".into(),
        "-o".into(),
        "LogLevel=ERROR".into(),
        format!("sprrw@{SSH_HOST}"),
    ];

    println!("Sandbox VM in {}", rundir.display());

    if args.vm_console {
        println!("Attaching serial console. Log in as sprrw / password.");
        println!("Quit QEMU with Ctrl-A x.");
        if !mounts.is_empty() {
            println!("Mount the shared directories inside the VM with:");
            for (i, mount) in mounts.iter().enumerate() {
                println!(
                    "  sudo mkdir -p {0} && sudo mount -t 9p -o trans=virtio,version=9p2000.L{1} sandboxshare{i} {0}",
                    mount.box_path,
                    if mount.read_only { ",ro" } else { "" }
                );
            }
        }
        println!();
        let code = Command::new(&qemu)
            .args(&qemu_args)
            .status()
            .map(|s| s.code().unwrap_or(1))
            .unwrap_or(1);
        let _ = fs::remove_dir_all(&rundir);
        return code;
    }

    let vm = Arc::new(Mutex::new(Vm {
        rundir: rundir.clone(),
        qemu_pid: None,
        ssh_base: ssh_base.clone(),
        keep_rundir: false,
    }));

    crate::install_shutdown_handler(vm.clone());

    let code = boot_and_run(
        args,
        &mounts,
        &qemu,
        &qemu_args,
        &ssh_base,
        serve_socket,
        &vm,
    );
    vm.lock().unwrap().shut_down();
    println!("Done!");
    code
}

fn boot_and_run(
    args: &Args,
    mounts: &[Mount],
    qemu: &Path,
    qemu_args: &[String],
    ssh_base: &[String],
    serve_socket: Option<&Path>,
    vm: &Arc<Mutex<Vm>>,
) -> i32 {
    let started = Instant::now();

    match Command::new(qemu).args(qemu_args).status() {
        Ok(status) if status.success() => {}
        _ => {
            eprintln!("Failed to start QEMU");
            vm.lock().unwrap().keep_rundir = true;
            return 1;
        }
    }

    let (pidfile, console_log) = {
        let guard = vm.lock().unwrap();
        (guard.rundir.join("pid"), guard.console_log())
    };

    let qemu_pid: i32 = match fs::read_to_string(&pidfile)
        .ok()
        .and_then(|text| text.trim().parse().ok())
    {
        Some(pid) => pid,
        None => {
            eprintln!("QEMU did not write a pid file");
            vm.lock().unwrap().keep_rundir = true;
            return 1;
        }
    };
    vm.lock().unwrap().qemu_pid = Some(qemu_pid);
    println!("Process id {qemu_pid}");

    let (program, options) = ssh_base.split_first().unwrap();
    let mut last_report = started;
    loop {
        if started.elapsed().as_secs_f64() > args.vm_timeout {
            eprintln!("VM unreachable after {}s", args.vm_timeout);
            eprintln!("{}", tail(&console_log, 4000));
            vm.lock().unwrap().keep_rundir = true;
            return 1;
        }

        let probe = Command::new(program)
            .args(["-o", "ConnectTimeout=1"])
            .args(options)
            .arg("true")
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();

        if probe.is_ok_and(|s| s.success()) {
            break;
        }

        if !pid_alive(qemu_pid) {
            eprintln!("QEMU exited before the VM became reachable.");
            eprintln!("{}", tail(&console_log, 4000));
            vm.lock().unwrap().keep_rundir = true;
            return 1;
        }

        if last_report.elapsed() >= Duration::from_secs(3) {
            println!(
                "  waiting for VM to finish booting ({}s)",
                started.elapsed().as_secs()
            );
            last_report = Instant::now();
        }

        std::thread::sleep(Duration::from_millis(100));
    }

    let mount_lines: Vec<String> = mounts
        .iter()
        .enumerate()
        .flat_map(|(i, mount)| {
            let opts = format!(
                "trans=virtio,version=9p2000.L{}",
                if mount.read_only { ",ro" } else { "" }
            );
            [
                format!("sudo mkdir -p \"{}\"", mount.box_path),
                format!(
                    "sudo mount -t 9p -o {opts} sandboxshare{i} \"{}\"",
                    mount.box_path
                ),
            ]
        })
        .collect();

    match serve_socket {
        Some(socket) => {
            if !mount_lines.is_empty() {
                let setup = Command::new(program)
                    .args(options)
                    .arg("-n")
                    .arg(remote_script(&mount_lines))
                    .output();
                match setup {
                    Ok(out) if out.status.success() => {}
                    Ok(out) => {
                        eprintln!("Failed to mount shared directories in the VM:");
                        eprintln!("{}", String::from_utf8_lossy(&out.stderr).trim());
                        vm.lock().unwrap().keep_rundir = true;
                        return 1;
                    }
                    Err(e) => {
                        eprintln!("Failed to mount shared directories in the VM: {e}");
                        vm.lock().unwrap().keep_rundir = true;
                        return 1;
                    }
                }
            }

            println!("Serving sandbox commands on {}", socket.display());
            let executor = bridge::Ssh {
                base: ssh_base.to_vec(),
                cwd: args.box_cwd().to_string(),
                grace: 5,
            };
            if let Err(e) = bridge::serve(socket, executor) {
                eprintln!("Failed to serve on {}: {e}", socket.display());
                return 1;
            }
            0
        }
        None => {
            let mut lines = mount_lines;
            lines.push(format!("cd {}", shlex::try_quote(args.box_cwd()).unwrap()));
            let exec = if args.exec.is_empty() {
                vec!["bash".to_string()]
            } else {
                args.exec.clone()
            };
            lines.push(format!(
                "exec {}",
                shlex::try_join(exec.iter().map(String::as_str)).unwrap()
            ));

            Command::new(program)
                .args(options)
                .arg("-t")
                .arg(remote_script(&lines))
                .status()
                .map(|s| s.code().unwrap_or(1))
                .unwrap_or(1)
        }
    }
}
