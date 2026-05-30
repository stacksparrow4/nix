import json
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
run_parser.set_defaults(type="bwrap")
run_parser.add_argument(
    "-c", "--cwd", action="store_true", help="Share the current working directory"
)
run_parser.add_argument(
    "-g", "--rogit", action="store_true", help="Make /pwd/.git in the sandbox read only"
)
run_parser.add_argument("-w", "--wayland", action="store_true", help="Share wayland")
run_parser.add_argument("-x", "--x11", action="store_true", help="Share X11")
# TODO: add downgradeterm and other missing things
run_parser.add_argument("-f", "--file", help="Load configuration from a JSON file")
run_parser.add_argument("exec", nargs="*")

exec_parser = subparsers.add_parser("exec", help="Execute a command inside a sandbox")

args = parser.parse_args()


@dataclass
class Mount:
    host_path: str
    box_path: str
    type: str = "unknown"
    ro: bool = False
    needs_create: bool = False

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
    # TODO: cancel if already in a sandbox
    if args.type == "bwrap":
        mounts = [
            Mount(
                f,
                "/home/sprrw/" + f.removeprefix("/etc/hm-package/home-files/"),
                "file",
                ro=True,
                needs_create=False,
            )
            for f in find_symlinks("/etc/hm-package/home-files")
        ]

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

        # TODO add user supplied mounts

        # TODO add user supplied env vars
        envvars = [
            "PATH=/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
            "__ETC_PROFILE_SOURCED=1",
            "IN_SPRRW_SANDBOX=1",
            "HOME=/home/sprrw",
            "EDITOR=" + ensure_env("EDITOR"),
            "NIX_PATH=" + ensure_env("NIX_PATH"),
        ]

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
            "--share-net",  # TODO: make this an option
            *(["--chdir", "/pwd"] if args.cwd else ["--chdir", "/home/sprrw"]),
            *[a for m in mounts for a in m.to_bwrap_args()],
            "/usr/bin/env",
            *envvars,
            *args.exec,
        ]

        # print(subprocess_args)

        exit(subprocess.run(subprocess_args).returncode)

raise NotImplementedError()
