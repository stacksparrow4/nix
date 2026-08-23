use std::io::Write;
use std::net::TcpListener;
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::Duration;

use crate::Cli;
use crate::common::{cwd, exit_code};
use crate::mount::{BOX_VM_CWD, Mount, MountType, build_stage_script, quote};

pub fn run(args: &Cli, volume_mounts: Vec<Mount>) -> ! {
    for v in &volume_mounts {
        if v.mount_type != MountType::Dir {
            println!(
                "VM backend only supports directory mounts, got {:?} for {}",
                v.mount_type, v.host_path
            );
            std::process::exit(1);
        }
    }

    let mut mounts = volume_mounts;

    if args.cwd {
        mounts.push(Mount::new(&cwd(), BOX_VM_CWD, MountType::Dir, false));
    }

    if args.ro_cwd {
        mounts.push(Mount::new(&cwd(), BOX_VM_CWD, MountType::Dir, true));
    }

    let ro_git = args.ro_git && Path::new("./.git").exists();

    let open_port = {
        TcpListener::bind("127.0.0.1:0")
            .ok()
            .map(|listener| listener.local_addr().unwrap().port())
            .expect("could not find open port")
    };

    println!("Forwarding SSH to port {open_port}");
    println!("Enter the VM yourself with:");
    println!(
        "sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p {open_port} localhost"
    );

    let stage = tempfile::Builder::new()
        .prefix("sprrw-sandbox-stage.")
        .tempdir()
        .expect("failed to create the stage directory")
        .keep();
    let stage = stage.to_string_lossy().into_owned();

    let mut virtfs_args: Vec<String> = Vec::new();
    for (i, m) in mounts.iter().enumerate() {
        virtfs_args.push("-virtfs".to_string());
        virtfs_args.push(format!(
            "local,path={stage}/{i},mount_tag=sandboxshare{i},security_model=none,id=host{i}{}",
            if m.ro { ",readonly=on" } else { "" }
        ));
    }

    let qemu_pid = {
        let piddir = tempfile::Builder::new()
            .prefix("sprrw-sandbox-qemu-pid.")
            .tempdir()
            .expect("failed to create the qemu pid directory");
        let pidfile_path = piddir.path().join("pid");

        let mut qemu_args: Vec<String> = [
            "qemu-system-x86_64",
            "-enable-kvm",
            "-m",
            "16384",
            "-smp",
            "4",
            "-cdrom",
            &format!(
                "{}/.local/vm.iso",
                std::env::var("HOME").expect("HOME is not set")
            ),
            "-boot",
            "d",
            "-nic",
            &format!("user,hostfwd=tcp:127.0.0.1:{open_port}-:22"),
            "-display",
            "none",
            "-daemonize",
        ]
        .iter()
        .map(|a| a.to_string())
        .collect();
        qemu_args.extend(virtfs_args);
        qemu_args.push("-pidfile".to_string());
        qemu_args.push(pidfile_path.to_string_lossy().into_owned());

        let mut stage_script = build_stage_script(&mounts, &stage, ro_git);
        stage_script.push(format!(
            "exec {}",
            qemu_args
                .iter()
                .map(|a| quote(a))
                .collect::<Vec<_>>()
                .join(" ")
        ));
        let stage_script = stage_script.join("\n");

        let status = Command::new("unshare")
            .args([
                "--mount",
                "--user",
                "--map-current-user",
                "--keep-caps",
                "--propagation",
                "private",
                "sh",
                "-c",
            ])
            .arg(&stage_script)
            .status()
            .unwrap_or_else(|err| {
                eprintln!("{err}");
                std::process::exit(1);
            });

        if !status.success() {
            println!("Failed to start QEMU");
            let _ = std::fs::remove_dir(&stage);
            std::process::exit(1);
        }

        std::fs::read_to_string(&pidfile_path)
            .expect("failed to read the qemu pid file")
            .trim()
            .parse::<i32>()
            .expect("failed to parse the qemu pid")
    };

    println!("Process id {qemu_pid}");

    let result = enter_vm(args, &mounts, open_port);

    println!("Terminating qemu...");
    unsafe { libc::kill(qemu_pid, libc::SIGTERM) };

    for _ in 0..50 {
        match std::fs::remove_dir(&stage) {
            Ok(()) => break,
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => break,
            Err(_) => std::thread::sleep(Duration::from_millis(100)),
        }
    }

    let return_code = match result {
        Ok(code) => code,
        Err(err) => {
            eprintln!("{err}");
            std::process::exit(1);
        }
    };

    println!("Done!");
    std::process::exit(return_code)
}

fn enter_vm(args: &Cli, mounts: &[Mount], open_port: u16) -> Result<i32, String> {
    let ssh_base: Vec<String> = [
        "-p",
        "password",
        "ssh",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        "-o",
        "LogLevel=ERROR",
        "localhost",
        "-p",
        &open_port.to_string(),
    ]
    .iter()
    .map(|a| a.to_string())
    .collect();

    let mut startup_lines: Vec<String> = Vec::new();
    for (i, m) in mounts.iter().enumerate() {
        startup_lines.push(format!("sudo mkdir -p \"{}\"", m.box_path));
        startup_lines.push(format!(
            "sudo mount -t 9p -o trans=virtio,version=9p2000.L sandboxshare{i} \"{}\"",
            m.box_path
        ));
    }
    if args.cwd || args.ro_cwd {
        startup_lines.push(format!("cd {}", BOX_VM_CWD));
    }
    startup_lines.push(
        args.exec
            .iter()
            .map(|a| quote(a))
            .collect::<Vec<_>>()
            .join(" "),
    );
    let startup_script = format!("{}\n", startup_lines.join("\n"));

    let mut upload = Command::new("sshpass")
        .args(&ssh_base)
        .arg("cat > /tmp/startup.sh")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|err| err.to_string())?;
    upload
        .stdin
        .take()
        .expect("stdin was piped")
        .write_all(startup_script.as_bytes())
        .map_err(|err| err.to_string())?;
    let upload = upload.wait_with_output().map_err(|err| err.to_string())?;
    if !upload.status.success() {
        return Err(format!("sshpass exited with {}", exit_code(&upload.status)));
    }

    let status = Command::new("sshpass")
        .args(&ssh_base)
        .args(["-t", "bash /tmp/startup.sh"])
        .status()
        .map_err(|err| err.to_string())?;

    Ok(exit_code(&status))
}
