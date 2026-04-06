#!/usr/bin/env python3

import sys
import subprocess
import os

end_bwrap_args_ind = sys.argv.index("ENDBWRAPARGS")

additional_bwrap_args = sys.argv[1:end_bwrap_args_ind]
vim_path = sys.argv[end_bwrap_args_ind + 1]
vim_args = sys.argv[end_bwrap_args_ind + 2 :]

additional_vim_args = []

proc_args = None

XDG_RUNTIME_DIR = os.getenv("XDG_RUNTIME_DIR")
assert XDG_RUNTIME_DIR is not None
WAYLAND_DISPLAY = os.getenv("WAYLAND_DISPLAY")
assert WAYLAND_DISPLAY is not None

SHARED_CONFIGS = [
    "/home/sprrw/.config/nvim",
    "/home/sprrw/.config/yazi",
    "/home/sprrw/.config/aichat",
]

default_bwrap_args = [
    "bwrap",
    "--unshare-all",
    "--as-pid-1",
    *["--ro-bind", "/nix/store", "/nix/store"],
    *["--ro-bind", "/bin", "/bin"],
    *["--ro-bind", "/usr", "/usr"],
    *["--ro-bind", "/etc", "/etc"],
    *["--ro-bind", "/usr", "/usr"],
    *["--ro-bind", "/run/current-system/sw", "/run/current-system/sw"],
    *[y for x in SHARED_CONFIGS for y in ["--ro-bind", x, x]],
    *["--tmpfs", "/tmp"],
    *["--proc", "/proc"],
    *["--dev", "/dev"],
    "--share-net",
    *[
        "--ro-bind",
        f"{XDG_RUNTIME_DIR}/{WAYLAND_DISPLAY}",
        f"{XDG_RUNTIME_DIR}/{WAYLAND_DISPLAY}",
    ],
]

share_dir = os.getcwd()
if len(vim_args) == 1 and vim_args[0].startswith("/"):
    arg = vim_args[0]
    if os.path.isdir(arg):
        share_dir = arg
        share_file = "."
    else:
        share_dir = os.path.dirname(arg)
        share_file = os.path.basename(arg)

    additional_vim_args.append(share_file)
else:
    additional_vim_args.extend(vim_args)

args = [
    *default_bwrap_args,
    *["--bind", share_dir, "/pwd"],
    *additional_bwrap_args,
    *["--chdir", "/pwd"],
    "--",
    "/usr/bin/env",
    "PATH=/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
    "XDG_RUNTIME_DIR=" + XDG_RUNTIME_DIR,
    "WAYLAND_DISPLAY=" + WAYLAND_DISPLAY,
    vim_path,
    *additional_vim_args,
]

exit_code = subprocess.call(args)

exit(exit_code)
