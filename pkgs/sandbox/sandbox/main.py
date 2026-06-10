import argparse
import os
import random
import shlex
import signal
import subprocess
import sys
import tempfile
import shutil
from pathlib import Path
from dataclasses import dataclass
from .nixstorefuse import start_overlay


@dataclass
class Mount:
    host_path: str
    box_path: str
    type: str = "unknown"
    ro: bool = False

    def to_bwrap_args(self):
        return ["--ro-bind" if self.ro else "--bind", self.host_path, self.box_path]


def find_symlinks(path):
    yield from (str(p) for p in Path(path).rglob("*") if p.is_symlink())


def ensure_env(key):
    r = os.getenv(key)
    if r is None:
        print("Env var", key, "is required but was not set")
        exit(1)
    return r


def main():
    parser = argparse.ArgumentParser(description="Manage NixOS lightweight sandboxes")

    backend = parser.add_mutually_exclusive_group()
    backend.add_argument(
        "--bwrap",
        action="store_const",
        const="bwrap",
        dest="type",
        help="Use bwrap backend (default)",
    )
    backend.add_argument(
        "--podman",
        action="store_const",
        const="podman",
        dest="type",
        help="Use podman backend",
    )
    backend.add_argument(
        "--vm", action="store_const", const="vm", dest="type", help="Use VM backend"
    )
    parser.add_argument(
        "-c", "--cwd", action="store_true", help="Share the current working directory"
    )
    parser.add_argument(
        "-g",
        "--ro-git",
        action="store_true",
        help="Make /pwd/.git in the sandbox read only",
        dest="ro_git",
    )
    parser.add_argument("-w", "--wayland", action="store_true", help="Share wayland")
    parser.add_argument("-x", "--x11", action="store_true", help="Share X11")
    parser.add_argument(
        "-v",
        "--volume",
        action="append",
        dest="volumes",
        help="Share volumes, form hostpath:boxpath:ro/rw:type",
    )
    parser.add_argument(
        "-n",
        "--no-network",
        action="store_true",
        help="Disable network",
        dest="no_network",
    )
    parser.add_argument(
        "-e",
        "--env",
        action="append",
        dest="env_vars",
        help="Provide environment variables",
    )
    parser.add_argument(
        "-d",
        "--downgrade-term",
        action="store_true",
        help="Use a standard terminal",
        dest="downgrade_term",
    )
    parser.add_argument(
        "-r",
        "--reset-env",
        action="store_true",
        help="Clear the environment variables before running",
        dest="reset_env",
    )
    parser.add_argument(
        "--nix-overlay",
        action="store_true",
        help="Enable Nix store overlay",
        dest="nix_overlay",
    )
    parser.add_argument(
        "--reset-on-done",
        action="store_true",
        help="Run the 'reset' command after the sandbox finishes",
        dest="reset_on_done",
    )
    parser.add_argument("exec", nargs="*")
    parser.set_defaults(type="bwrap", volumes=[], env_vars=[])

    args = parser.parse_args()

    if args.ro_git and not args.cwd:
        print("Cannot specify --ro-git without --cwd")
        exit(1)

    if len(args.exec) == 0:
        args.exec = ["bash"]

    if os.getenv("IN_SPRRW_SANDBOX") is not None:
        exit(subprocess.run(args.exec).returncode)

    volume_mounts = []
    for v in args.volumes:
        components = v.split(":")
        ro = False
        if len(components) >= 3:
            if components[2] == "ro":
                ro = True
            elif components[2] == "rw":
                ro = False
            else:
                print("The mount", v, "has invalid type", components[2])
                exit(1)
        volume_mounts.append(
            Mount(
                components[0],
                components[1],
                type=components[3] if len(components) >= 4 else "unknown",
                ro=ro,
            )
        )

    for v in volume_mounts:
        if not os.path.exists(v.host_path):
            if v.type == "unknown":
                print(
                    "The mount",
                    v,
                    "did not exist on the host and no type was specified to autocreate with",
                )
                exit(1)
            elif v.type == "dir":
                os.makedirs(v.host_path)
            elif v.type == "file":
                Path(v.host_path).touch()
            else:
                print("Invalid type for", v, ":", v.type)

    if args.type == "bwrap":
        mounts = [
            Mount(
                f,
                "/home/sprrw/" + f.removeprefix("/etc/hm-package/home-files/"),
                "file",
                ro=True,
            )
            for f in find_symlinks("/etc/hm-package/home-files")
        ]

        mounts.extend(volume_mounts)

        if args.cwd:
            mounts.append(Mount(str(Path.cwd()), "/pwd", "dir"))

        if args.ro_git and os.path.exists("./.git"):
            mounts.append(Mount(str(Path.cwd() / ".git"), "/pwd/.git", "dir", ro=True))

        if args.wayland:
            mounts.append(
                Mount(
                    ensure_env("XDG_RUNTIME_DIR") + "/" + ensure_env("WAYLAND_DISPLAY"),
                    "/tmp/wayland-1",
                    "file",
                    ro=True,
                )
            )

        if args.x11:
            mounts.append(Mount("/tmp/.X11-unix", "/tmp/.X11-unix", "dir", ro=True))

        mounts.extend(
            [
                Mount("/bin", "/bin", "dir", ro=True),
                Mount("/etc", "/etc", "dir", ro=True),
                Mount("/usr", "/usr", "dir", ro=True),
                Mount("/lib64", "/lib64", "dir", ro=True),
                Mount(
                    "/run/current-system/sw",
                    "/run/current-system/sw",
                    "dir",
                    ro=True,
                ),
                Mount("/home/sprrw/nixos", "/home/sprrw/nixos", "dir", ro=True),
            ]
        )

        envvars = args.env_vars + [
            "PATH=/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
            "__ETC_PROFILE_SOURCED=1",
            "IN_SPRRW_SANDBOX=1",
            "HOME=/home/sprrw",
            "EDITOR=" + ensure_env("EDITOR"),
            "NIX_PATH=" + ensure_env("NIX_PATH"),
            "COLORTERM=truecolor",
        ]

        if args.downgrade_term:
            envvars.extend(["TERM=xterm-256color"])
        else:
            envvars.extend(["TERM=" + ensure_env("TERM")])

        if args.wayland:
            envvars.extend(
                [
                    "WAYLAND_DISPLAY=wayland-1",
                    "XDG_RUNTIME_DIR=/tmp",
                    "GTK_THEME=" + ensure_env("GTK_THEME"),
                ]
            )

        if args.x11:
            envvars.append("DISPLAY=" + ensure_env("DISPLAY"))

        nix_store_args = [
            "--ro-bind",
            "/nix/store",
            "/nix/store",
        ]
        store_upper = None
        store_mount = None
        store_var = None
        if args.nix_overlay:
            store_upper = tempfile.mkdtemp(prefix="sprrw-sandbox-upper.")
            store_mount = tempfile.mkdtemp(prefix="sprrw-sandbox-fuse.")
            store_var = tempfile.mkdtemp(prefix="sprrw-sandbox-var.")
            start_overlay("/nix/store", store_upper, store_mount)

            # Set up /nix/var/nix
            try:
                shutil.copytree(
                    "/nix/var/nix/db",
                    store_var + "/db",
                    symlinks=True,
                    dirs_exist_ok=True,
                )
            except shutil.Error:
                pass
            try:
                shutil.copytree(
                    "/nix/var/nix/gcroots",
                    store_var + "/gcroots",
                    symlinks=True,
                    dirs_exist_ok=True,
                )
            except shutil.Error:
                pass
            os.mkdir(store_var + "/temproots")
            os.mkdir(store_var + "/profiles")
            os.mkdir(store_var + "/daemon-socket")

            nix_store_args = [
                "--bind",
                store_mount,
                "/nix/store",
                "--bind",
                store_var,
                "/nix/var/nix",
            ]

        subprocess_args = [
            "bwrap",
            "--unshare-all",
            "--as-pid-1",
            "--die-with-parent",
            "--tmpfs",
            "/tmp",
            "--proc",
            "/proc",
            "--dev",
            "/dev",
            "--dir",
            "/home/sprrw",
            *nix_store_args,
            *([] if args.no_network else ["--share-net"]),
            *(["--chdir", "/pwd"] if args.cwd else ["--chdir", "/home/sprrw"]),
            *[a for m in mounts for a in m.to_bwrap_args()],
            "/usr/bin/env",
            *envvars,
            *args.exec,
        ]

        # print(subprocess_args)

        return_code = 1
        proc = subprocess.Popen(
                subprocess_args, env=({} if args.reset_env else None)
            )
        try:
            return_code = proc.wait()
        except Exception as e:
            print(e)
            proc.kill()
        finally:
            if args.nix_overlay:
                assert (
                    store_mount is not None
                    and store_upper is not None
                    and store_var is not None
                )
                subprocess.run(["fusermount", "-u", store_mount])
                shutil.rmtree(store_upper)
                shutil.rmtree(store_mount)
                shutil.rmtree(store_var)

            if args.reset_on_done:
                try:
                    if sys.stdin.isatty():
                        old = signal.signal(signal.SIGTTOU, signal.SIG_IGN)
                        try:
                            os.tcsetpgrp(sys.stdin.fileno(), os.getpgrp())
                        finally:
                            signal.signal(signal.SIGTTOU, old)
                except (OSError, ValueError):
                    pass
                subprocess.run(["reset"])

        exit(return_code)

    elif args.type == "vm":
        # All VM shared paths must be directories
        for v in volume_mounts:
            if v.type != "dir":
                print(
                    "VM backend only supports directory mounts, got",
                    v.type,
                    "for",
                    v.host_path,
                )
                exit(1)

        mounts = list(volume_mounts)

        if args.cwd:
            mounts.append(Mount(str(Path.cwd()), "/pwd", "dir"))

        if args.ro_git and os.path.exists("./.git"):
            mounts.append(Mount(str(Path.cwd() / ".git"), "/pwd/.git", "dir", ro=True))

        # Find an open port in the ephemeral range
        used_ports = set()
        ss_output = subprocess.run(
            ["ss", "-tan"], capture_output=True, text=True
        ).stdout
        for line in ss_output.splitlines():
            parts = line.split()
            if len(parts) >= 4:
                addr = parts[3]
                if ":" in addr:
                    port_str = addr.rsplit(":", 1)[-1]
                    if port_str.isdigit():
                        used_ports.add(int(port_str))

        candidates = [p for p in range(49152, 65536) if p not in used_ports]
        open_port = random.choice(candidates)

        print(f"Forwarding SSH to port {open_port}")
        print("Enter the VM yourself with:")
        print(
            f"sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {open_port} localhost"
        )

        virtfs_args = []
        for i, m in enumerate(mounts):
            virtfs_args.extend(
                [
                    "-virtfs",
                    f"local,path={m.host_path},mount_tag=sandboxshare{i},security_model=none,id=host{i}{',readonly=on' if m.ro else ''}",
                ]
            )

        with tempfile.TemporaryDirectory(prefix="sprrw-sandbox-qemu-pid.") as piddir:
            pidfile_path = os.path.join(piddir, "pid")
            qemu_args = [
                "qemu-system-x86_64",
                "-enable-kvm",
                "-m",
                "16384",
                "-smp",
                "4",
                "-cdrom",
                os.path.expanduser("~/.local/vm.iso"),
                "-boot",
                "d",
                "-nic",
                f"user,hostfwd=tcp:127.0.0.1:{open_port}-:22",
                "-display",
                "none",
                "-daemonize",
                *virtfs_args,
                "-pidfile",
                pidfile_path,
            ]

            result = subprocess.run(qemu_args)
            if result.returncode != 0:
                print("Failed to start QEMU")
                exit(1)

            with open(pidfile_path) as f:
                qemu_pid = int(f.read().strip())

        print(f"Process id {qemu_pid}")

        return_code = 1
        try:
            ssh_base = [
                "sshpass",
                "-p",
                "password",
                "ssh",
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
                "localhost",
                "-p",
                str(open_port),
            ]

            startup_lines = []
            for i, m in enumerate(mounts):
                startup_lines.append(f'sudo mkdir -p "{m.box_path}"')
                startup_lines.append(
                    f'sudo mount -t 9p -o trans=virtio,version=9p2000.L sandboxshare{i} "{m.box_path}"'
                )
            if args.cwd:
                startup_lines.append("cd /pwd")
            startup_lines.append(" ".join(shlex.quote(a) for a in args.exec))
            startup_script = "\n".join(startup_lines) + "\n"

            _ = subprocess.run(
                [*ssh_base, "cat > /tmp/startup.sh"],
                input=startup_script,
                text=True,
                capture_output=True,
                check=True,
            )

            return_code = subprocess.run(
                [*ssh_base, "-t", "bash /tmp/startup.sh"],
            ).returncode
        finally:
            print("Terminating qemu...")
            try:
                os.kill(qemu_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

        print("Done!")
        exit(return_code)

    raise NotImplementedError()
