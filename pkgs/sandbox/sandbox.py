import argparse
import os
import subprocess
from pathlib import Path
from dataclasses import dataclass

parser = argparse.ArgumentParser(description="Manage NixOS lightweight sandboxes")
subparsers = parser.add_subparsers(dest="subcommand", required=True)

run_parser = subparsers.add_parser("run", help="Run a new sandbox")
backend = run_parser.add_mutually_exclusive_group()
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
run_parser.add_argument(
    "-c", "--cwd", action="store_true", help="Share the current working directory"
)
run_parser.add_argument(
    "-g",
    "--ro-git",
    action="store_true",
    help="Make /pwd/.git in the sandbox read only",
    dest="rogit",
)
run_parser.add_argument("-w", "--wayland", action="store_true", help="Share wayland")
run_parser.add_argument("-x", "--x11", action="store_true", help="Share X11")
run_parser.add_argument(
    "-v",
    "--volume",
    nargs="*",
    dest="volumes",
    help="Share volumes, form hostpath:boxpath:ro/rw:type",
)
run_parser.add_argument(
    "-n", "--no-network", action="store_true", help="Disable network", dest="nonetwork"
)
run_parser.add_argument(
    "-e",
    "--env",
    nargs="*",
    dest="envvars",
    help="Provide environment variables",
)
run_parser.add_argument(
    "-d",
    "--downgrade-term",
    action="store_true",
    help="Use a standard terminal",
    dest="downgradeterm",
)
run_parser.add_argument(
    "-r",
    "--reset-env",
    action="store_true",
    help="Clear the environment variables before running",
    dest="resetenv",
)
run_parser.add_argument("exec", nargs="+")
run_parser.set_defaults(type="bwrap", volumes=[], envvars=[])

exec_parser = subparsers.add_parser("exec", help="Execute a command inside a sandbox")

args = parser.parse_args()


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


if args.subcommand == "run":
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

        if args.rogit:
            if not args.cwd:
                print("Cannot specify --rogit without --cwd")
                exit(1)

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
                Mount(
                    "/run/current-system/sw", "/run/current-system/sw", "dir", ro=True
                ),
                Mount("/home/sprrw/nixos", "/home/sprrw/nixos", "dir", ro=True),
            ]
        )

        envvars = args.envvars + [
            "PATH=/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
            "__ETC_PROFILE_SOURCED=1",
            "IN_SPRRW_SANDBOX=1",
            "HOME=/home/sprrw",
            "EDITOR=" + ensure_env("EDITOR"),
            "NIX_PATH=" + ensure_env("NIX_PATH"),
            "COLORTERM=truecolor",
        ]

        if args.downgradeterm:
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

        subprocess_args = [
            "bwrap",
            "--unshare-all",
            "--as-pid-1",
            "--tmpfs",
            "/tmp",
            "--proc",
            "/proc",
            "--dev",
            "/dev",
            "--dir",
            "/home/sprrw",
            # TODO: replace this with fuse
            "--ro-bind",
            "/nix/store",
            "/nix/store",
            *([] if args.nonetwork else ["--share-net"]),
            *(["--chdir", "/pwd"] if args.cwd else ["--chdir", "/home/sprrw"]),
            *[a for m in mounts for a in m.to_bwrap_args()],
            "/usr/bin/env",
            *envvars,
            *args.exec,
        ]

        # print(subprocess_args)

        exit(
            subprocess.run(
                subprocess_args, env=({} if args.resetenv else None)
            ).returncode
        )

raise NotImplementedError()
