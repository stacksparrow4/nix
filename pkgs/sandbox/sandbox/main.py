import argparse
import base64
import os
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from dataclasses import dataclass

from . import bridge

# Substituted with absolute store paths at build time (see ../default.nix). Left
# as-is when running from a source checkout, in which case we fall back to PATH.
# QEMU is deliberately *not* substituted: that would drag its ~1GB closure into
# the closure of this package, and therefore into the sandbox VM image itself.
SOCAT = "@socat@"
SSH = "@ssh@"
SSH_KEYGEN = "@sshKeygen@"

# Arbitrary; only used for known_hosts matching, since we reach the VM through a
# unix socket rather than a hostname.
VM_SSH_HOST = "sandbox-vm"


def tool(substituted, fallback):
    if not substituted.startswith("@"):
        return substituted
    found = shutil.which(fallback)
    if found is None:
        print("Required program", fallback, "was not found on PATH")
        exit(1)
    return found


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


def own_executable():
    """Path to this program, for re-invoking ourselves inside a sandbox.

    It has to resolve into /nix/store, because that is the only tree mounted into
    the sandbox wholesale -- a path like ./sandbox/main.py from a source checkout
    is not visible in there. It also has to be the wrapper script rather than the
    Python module, since the wrapper is what sets PYTHONPATH (the sandbox does not
    inherit the caller's environment).
    """
    candidates = []
    if sys.argv[0]:
        if os.path.isabs(sys.argv[0]):
            candidates.append(sys.argv[0])
        from_path = shutil.which(os.path.basename(sys.argv[0]))
        if from_path:
            candidates.append(from_path)
    from_name = shutil.which("sandbox")
    if from_name:
        candidates.append(from_name)

    for candidate in candidates:
        resolved = os.path.realpath(candidate)
        if resolved.startswith("/nix/store/") and os.access(resolved, os.X_OK):
            return resolved

    print(
        "--serve needs to re-invoke this program inside the sandbox, but could not\n"
        "find it in /nix/store (tried: "
        + (", ".join(candidates) or "nothing")
        + ").\nRun the installed `sandbox` rather than a source checkout."
    )
    exit(1)


def pid_alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def run_probe(cmd, timeout):
    """Run cmd with a hard timeout, returning (returncode, message).

    On timeout the whole process group is killed, so that ssh's ProxyCommand
    helper does not linger once ssh itself is gone.
    """
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    try:
        _, err = proc.communicate(timeout=timeout)
        return proc.returncode, (err or "").strip() or "no error output"
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.communicate()
        return None, (
            "ssh timed out; the guest is not accepting connections on "
            "10.0.2.15:22 (is sshd.socket running, and does the guest have "
            "that address?)"
        )


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
        "--ro-cwd",
        action="store_true",
        help="Share the current working directory read only",
        dest="ro_cwd",
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
        "--vm-memory",
        type=int,
        default=8192,
        dest="vm_memory",
        help="VM backend: memory in MiB",
    )
    parser.add_argument(
        "--vm-cpus",
        type=int,
        default=2,
        dest="vm_cpus",
        help="VM backend: number of vCPUs. Keep well under nproc; several "
        "sandboxes may run concurrently",
    )
    parser.add_argument(
        "--vm-timeout",
        type=float,
        default=120.0,
        dest="vm_timeout",
        help="VM backend: seconds to wait for the VM to become reachable",
    )
    parser.add_argument(
        "--vm-console",
        action="store_true",
        dest="vm_console",
        help="VM backend: attach an interactive serial console instead of "
        "connecting over SSH, for debugging boot problems. Quit with Ctrl-A x",
    )
    parser.add_argument(
        "--serve",
        metavar="SOCKET",
        help="Keep one sandbox alive and serve commands into it over a unix "
        "socket at SOCKET, instead of running a command interactively. The "
        "socket is bound only once the sandbox is ready, so its existence can "
        "be used as a readiness signal",
    )
    parser.add_argument(
        # Internal: this is how --serve runs the bridge inside a bwrap sandbox.
        "--serve-agent",
        dest="serve_agent",
        metavar="SOCKET",
        help=argparse.SUPPRESS,
    )
    parser.add_argument("exec", nargs="*")
    parser.set_defaults(type="bwrap", volumes=[], env_vars=[])

    args = parser.parse_args()

    # Must precede the IN_SPRRW_SANDBOX check below: the agent runs inside a
    # sandbox, where that variable is set.
    if args.serve_agent is not None:
        bridge.install_termination_handlers()
        bridge.serve_forever(args.serve_agent, bridge.local_executor)
        exit(0)

    if args.ro_git and not args.cwd:
        print("Cannot specify --ro-git without --cwd")
        exit(1)

    if args.cwd and args.ro_cwd:
        print("Cannot specify --ro-cwd with --cwd")
        exit(1)

    serve_socket = None
    if args.serve is not None:
        if len(args.exec) > 0:
            print("Cannot specify a command with --serve")
            exit(1)
        if args.type == "podman":
            print("--serve is not supported by the podman backend")
            exit(1)
        if args.vm_console:
            print("Cannot specify --vm-console with --serve")
            exit(1)

        serve_socket, problem = bridge.validate_socket_path(args.serve)
        if problem is not None:
            print("--serve socket path", problem)
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

        if args.ro_cwd:
            mounts.append(Mount(str(Path.cwd()), "/pwd", "dir", ro=True))

        if args.ro_git and os.path.exists("./.git"):
            mounts.append(Mount(str(Path.cwd() / ".git"), "/pwd/.git", "dir", ro=True))

        if serve_socket is not None:
            # The agent runs inside the box and binds the socket itself, so the
            # directory holding it has to be visible in there at the same path.
            # This bind is emitted after --tmpfs /tmp, so a socket under /tmp
            # survives rather than being hidden by the tmpfs -- do not reorder.
            mounts.append(
                Mount(str(serve_socket.parent), str(serve_socket.parent), "dir")
            )
            args.exec = [own_executable(), "--serve-agent", str(serve_socket)]

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
            "PATH="
            + ("" if args.reset_env else ensure_env("PATH") + ":")
            + "/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
            "__ETC_PROFILE_SOURCED=1",
            "IN_SPRRW_SANDBOX=1",
            "HOME=/home/sprrw",
            "EDITOR=" + ensure_env("EDITOR"),
            "NIX_PATH=" + ensure_env("NIX_PATH"),
            "COLORTERM=truecolor",
            "TEMPDIR=/tmp",
            "TMPDIR=/tmp",
            "TEMP=/tmp",
            "TMP=/tmp",
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

        subprocess_args = [
            "bwrap",
            "--unshare-all",
            # --as-pid-1 suppresses bwrap's own PID 1 reaper. The interactive
            # case wants that, but the long-lived server does not: commands can
            # leave orphans behind, and without a reaper they would accumulate as
            # zombies for the lifetime of the session.
            *([] if serve_socket is not None else ["--as-pid-1"]),
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
            *(
                ["--chdir", "/pwd"]
                if args.cwd or args.ro_cwd
                else ["--chdir", "/home/sprrw"]
            ),
            *[a for m in mounts for a in m.to_bwrap_args()],
            "/usr/bin/env",
            *envvars,
            *args.exec,
        ]

        # print(subprocess_args)

        return_code = 1
        proc = subprocess.Popen(subprocess_args, env=({} if args.reset_env else None))
        try:
            return_code = proc.wait()
        except KeyboardInterrupt:
            # SIGINT was already delivered to the child by the terminal;
            # just wait for it to exit so we can report its return code.
            try:
                return_code = proc.wait()
            except KeyboardInterrupt:
                proc.kill()
                return_code = proc.wait()
        except Exception as e:
            print(e)
            proc.kill()

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

        if args.ro_cwd:
            mounts.append(Mount(str(Path.cwd()), "/pwd", "dir", ro=True))

        if args.ro_git and os.path.exists("./.git"):
            mounts.append(Mount(str(Path.cwd() / ".git"), "/pwd/.git", "dir", ro=True))

        boot_dir = Path(os.path.expanduser("~/.local/vm-boot"))
        if not boot_dir.is_dir():
            print(boot_dir, "does not exist. Run `build-vm` first.")
            exit(1)

        # QEMU is looked up on PATH rather than baked in, so that this package's
        # closure (which is installed *inside* the sandbox VM too) stays small.
        qemu = shutil.which("qemu-system-x86_64")
        if qemu is None:
            print("Required program qemu-system-x86_64 was not found on PATH")
            exit(1)

        socat = tool(SOCAT, "socat")
        ssh = tool(SSH, "ssh")
        ssh_keygen = tool(SSH_KEYGEN, "ssh-keygen")

        # Private per-VM directory holding the control socket and credentials.
        # Nothing in here is reachable from inside any sandbox.
        #
        # Its path must not contain '-'. QEMU <= 10.2 splits a
        # `hostfwd=unix:<path>-:<port>` rule at the *first* hyphen in the rule
        # rather than the last (net/slirp.c get_str_sep is called with '-', i.e.
        # strchr; only later versions pass `0 - '-'` to get strrchr). A hyphen
        # anywhere in the socket path is therefore taken as the host/guest
        # separator, and the rule is rejected with "Bad guest address".
        runtime_base = None
        for candidate in (
            os.environ.get("XDG_RUNTIME_DIR"),
            tempfile.gettempdir(),
            "/tmp",
        ):
            if candidate and os.path.isdir(candidate) and "-" not in candidate:
                runtime_base = candidate
                break

        if runtime_base is None:
            print(
                "Could not find a hyphen-free directory to hold the VM control",
                "socket (tried $XDG_RUNTIME_DIR, $TMPDIR and /tmp)",
            )
            exit(1)

        rundir = Path(tempfile.mkdtemp(prefix="sandboxvm.", dir=runtime_base))
        os.chmod(rundir, 0o700)

        ssh_sock = rundir / "ssh.sock"
        if "-" in str(ssh_sock):
            print(f"VM control socket path must not contain '-': {ssh_sock}")
            shutil.rmtree(rundir, ignore_errors=True)
            exit(1)
        console_log = rundir / "console.log"
        pidfile = rundir / "pid"
        host_key = rundir / "host_key"
        client_key = rundir / "id"
        known_hosts = rundir / "known_hosts"

        (rundir / "info").write_text(f"{Path.cwd()} :: {' '.join(args.exec)}\n")

        # Fresh keypairs per VM. The guest no longer generates host keys at boot
        # (the upstream default is RSA-4096, regenerated on every boot because
        # the live ISO has a fresh tmpfs /etc, blocking sshd for seconds).
        # ed25519 keygen on the host is ~5ms.
        for key in (host_key, client_key):
            subprocess.run(
                [ssh_keygen, "-q", "-t", "ed25519", "-N", "", "-C", "", "-f", str(key)],
                check=True,
            )

        known_hosts.write_text(
            f"{VM_SSH_HOST} {(rundir / 'host_key.pub').read_text().strip()}\n"
        )

        def write_credential(name, data):
            # systemd's PID 1 picks these up from SMBIOS type 11 OEM strings and
            # exposes them in /run/credentials/@system. Passing them via a file
            # (`-smbios type=11,path=`) avoids having to escape commas.
            path = rundir / f"cred.{name}"
            path.write_bytes(
                b"io.systemd.credential.binary:"
                + name.encode()
                + b"="
                + base64.b64encode(data)
            )
            path.chmod(0o600)
            return path

        host_key_cred = write_credential("sandbox.host_key", host_key.read_bytes())
        authorized_keys_cred = write_credential(
            "sandbox.authorized_keys", (rundir / "id.pub").read_bytes()
        )

        virtfs_args = []
        for i, m in enumerate(mounts):
            virtfs_args.extend(
                [
                    "-virtfs",
                    f"local,path={m.host_path},mount_tag=sandboxshare{i},"
                    f"security_model=none,id=host{i}"
                    + (",readonly=on" if m.ro else ""),
                ]
            )

        # A unix socket instead of a forwarded TCP port. Two reasons: it removes
        # the TOCTOU race in picking a free ephemeral port, and it makes the VM
        # unreachable from other guests. slirp rewrites guest traffic to
        # 10.0.2.2 into host loopback connections and offers no way to turn that
        # off, so a TCP hostfwd let any sandbox connect to any other sandbox's
        # sshd.
        netdev_opts = ["user", "id=net0", f"hostfwd=unix:{ssh_sock}-:22"]
        if args.no_network:
            # Drops all guest-initiated traffic while still serving the
            # pre-existing hostfwd socket.
            netdev_opts.append("restrict=on")

        qemu_args = [
            qemu,
            "-nodefaults",
            "-machine",
            "q35,accel=kvm",
            # The default qemu64 model hides AES-NI/AVX/RDRAND from the guest.
            "-cpu",
            "host",
            "-m",
            str(args.vm_memory),
            "-smp",
            str(args.vm_cpus),
            # Direct kernel boot: no SeaBIOS, no isolinux, and the initrd comes
            # straight out of the host page cache.
            "-kernel",
            str(boot_dir / "kernel"),
            "-initrd",
            str(boot_dir / "initrd"),
            "-append",
            (boot_dir / "cmdline").read_text().strip(),
            # Read-only for every VM, and virtio-blk rather than the emulated
            # ATAPI cdrom this used to boot from.
            "-drive",
            f"file={boot_dir / 'image.iso'},format=raw,if=none,id=iso,readonly=on",
            "-device",
            "virtio-blk-pci,drive=iso",
            # Host entropy, so guest crypto never waits on a cold entropy pool.
            "-device",
            "virtio-rng-pci",
            "-netdev",
            ",".join(netdev_opts),
            "-device",
            "virtio-net-pci,netdev=net0",
            "-smbios",
            f"type=11,path={host_key_cred}",
            "-smbios",
            f"type=11,path={authorized_keys_cred}",
            *virtfs_args,
            "-display",
            "none",
        ]

        if args.vm_console:
            # Serial multiplexed onto our stdio, in the foreground.
            qemu_args += ["-serial", "mon:stdio"]
        else:
            qemu_args += [
                "-serial",
                f"file:{console_log}",
                "-daemonize",
                "-pidfile",
                str(pidfile),
            ]

        ssh_base = [
            ssh,
            "-F",
            "/dev/null",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            f"IdentityFile={client_key}",
            "-o",
            "PreferredAuthentications=publickey",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            f"UserKnownHostsFile={known_hosts}",
            "-o",
            f"ProxyCommand={socat} - UNIX-CONNECT:{ssh_sock}",
            "-o",
            "ControlMaster=auto",
            "-o",
            f"ControlPath={rundir / 'cm'}",
            "-o",
            # A server has no long-running session holding the master open, so
            # persist it indefinitely and tear it down explicitly below.
            "ControlPersist=yes" if serve_socket is not None else "ControlPersist=60",
            "-o",
            "ConnectTimeout=5",
            "-o",
            "LogLevel=ERROR",
            f"sprrw@{VM_SSH_HOST}",
        ]

        print(f"Sandbox VM in {rundir}")

        if args.vm_console:
            print("Attaching serial console. Log in as sprrw / password.")
            print("Quit QEMU with Ctrl-A x.")
            if mounts:
                print("Mount the shared directories inside the VM with:")
                for i, m in enumerate(mounts):
                    opts = "trans=virtio,version=9p2000.L" + (",ro" if m.ro else "")
                    print(
                        f"  sudo mkdir -p {m.box_path} && "
                        f"sudo mount -t 9p -o {opts} sandboxshare{i} {m.box_path}"
                    )
            print()
            try:
                return_code = subprocess.run(qemu_args).returncode
            finally:
                shutil.rmtree(rundir, ignore_errors=True)
            exit(return_code)

        print("Enter the VM yourself with: vm-enter")

        qemu_pid = None
        return_code = 1
        keep_rundir = False

        if serve_socket is not None:
            # Installed before qemu starts, so a SIGTERM at any point from here on
            # unwinds through the cleanup below instead of orphaning the VM. Only
            # done when serving: turning SIGINT into an exit would break Ctrl-C
            # inside an interactive session.
            bridge.install_termination_handlers()

        try:
            if subprocess.run(qemu_args).returncode != 0:
                print("Failed to start QEMU")
                keep_rundir = True
                exit(1)

            qemu_pid = int(pidfile.read_text().strip())
            print(f"Process id {qemu_pid}")

            # Poll until sshd answers. The successful probe establishes the
            # ControlMaster, so the real invocation below reuses that connection
            # and pays no second handshake.
            #
            # Each probe needs a hard timeout. If the guest is up but nothing is
            # listening on port 22, slirp keeps retransmitting the forwarded SYN
            # and ssh blocks indefinitely -- ConnectTimeout does not apply,
            # because with a ProxyCommand ssh never performs a TCP connect
            # itself.
            # ssh applies ConnectTimeout to the *banner* exchange as well as to
            # the TCP connect (ssh.c passes it to kex_exchange_identification).
            # While the guest is still booting, QEMU's unix socket accepts
            # immediately and slirp then retransmits to a guest that isn't
            # answering yet, so the connection is established but silent and each
            # probe burns the full ConnectTimeout. Use a short one here so we
            # notice sshd coming up promptly; the real session below keeps the
            # longer value. ssh takes the first value given for an option, so
            # prepending this overrides the one in ssh_base.
            probe_cmd = [ssh, "-o", "ConnectTimeout=1", *ssh_base[1:], "true"]

            started = time.monotonic()
            deadline = started + args.vm_timeout
            last_report = started
            last_error = ""

            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    print(f"VM unreachable after {args.vm_timeout}s: {last_error}")
                    keep_rundir = True
                    exit(1)

                rc, last_error = run_probe(probe_cmd, min(10.0, max(2.0, remaining)))
                if rc == 0:
                    break

                if not pid_alive(qemu_pid):
                    print("QEMU exited before the VM became reachable.")
                    keep_rundir = True
                    exit(1)

                # Deliberately does not echo ssh's error. Until sshd is up every
                # probe legitimately fails, and printing "Connection timed out
                # during banner exchange" each time just looks like a fault.
                now = time.monotonic()
                if now - last_report >= 3.0:
                    print(f"  waiting for VM to finish booting ({int(now - started)}s)")
                    last_report = now

                time.sleep(0.1)

            mount_lines = []
            for i, m in enumerate(mounts):
                opts = "trans=virtio,version=9p2000.L" + (",ro" if m.ro else "")
                mount_lines.append(f'sudo mkdir -p "{m.box_path}"')
                mount_lines.append(
                    f'sudo mount -t 9p -o {opts} sandboxshare{i} "{m.box_path}"'
                )

            box_cwd = "/pwd" if (args.cwd or args.ro_cwd) else "/home/sprrw"

            def remote_script(lines):
                script = "\n".join(lines) + "\n"
                payload = base64.b64encode(script.encode()).decode()
                return (
                    f"printf %s {shlex.quote(payload)} | base64 -d > /tmp/startup.sh"
                    " && exec bash /tmp/startup.sh"
                )

            if serve_socket is not None:
                # Apply the 9p mounts once, then serve commands into the VM. The
                # box outlives individual commands, so files and background
                # processes persist across them exactly as in the bwrap backend.
                if mount_lines:
                    setup = subprocess.run(
                        [*ssh_base, "-n", remote_script(mount_lines)],
                        capture_output=True,
                        text=True,
                    )
                    if setup.returncode != 0:
                        print("Failed to mount shared directories in the VM:")
                        print(setup.stderr.strip())
                        keep_rundir = True
                        exit(1)

                print(f"Serving sandbox commands on {serve_socket}")
                bridge.serve_forever(
                    str(serve_socket), bridge.make_ssh_executor(ssh_base, box_cwd)
                )
                return_code = 0
            else:
                lines = [*mount_lines, f"cd {shlex.quote(box_cwd)}"]
                lines.append("exec " + " ".join(shlex.quote(a) for a in args.exec))

                # A single multiplexed session, rather than one connection to
                # upload the script and a second one to run it.
                return_code = subprocess.run(
                    [*ssh_base, "-t", remote_script(lines)]
                ).returncode
        finally:
            print("Terminating qemu...")
            subprocess.run([*ssh_base, "-O", "exit"], capture_output=True)
            if qemu_pid is not None:
                try:
                    os.kill(qemu_pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass

            if keep_rundir:
                # Leave the console log and keys in place; deleting them is what
                # makes a failure to boot hard to diagnose.
                print(f"Kept VM state for debugging in {rundir}")
                print(f"  full boot log: {console_log}")
                print("  for an interactive serial console, re-run with --vm-console")
                print(f"  rm -rf {rundir}   # when done")
            else:
                shutil.rmtree(rundir, ignore_errors=True)

        print("Done!")
        exit(return_code)

    raise NotImplementedError()


if __name__ == "__main__":
    main()
