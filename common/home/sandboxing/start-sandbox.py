#!/usr/bin/env python3

"""
Usage:

start-sandbox.py /path/to/dockerinit arg1 arg2 DOCKERIMG arg3 arg4 arg5

args before DOCKERIMG will be before the docker image (arguments to docker)
args after DOCKERIMG will be after the docker image (process to exec in container)
"""

import sys
import subprocess
import os

dockerInit = sys.argv[1]

beforeTargetArgs = sys.argv[2:sys.argv.index("DOCKERIMG")]
afterTargetArgs = sys.argv[sys.argv.index("DOCKERIMG")+1:]

args = [
    "docker", "run",
    "--rm",
    "--hostname", "sandbox",
    "-v", "/nix:/nix:ro",
    "-v", "/etc/fonts:/etc/fonts:ro",
    "-v", "/etc/hm-package:/etc/hm-package:ro",
    "-v", f"{os.path.expanduser("~/nixos")}:/home/sprrw/nixos:ro",
    "-u", "1000:100",
    "-e", "TERM",
    *beforeTargetArgs,
    "usermapped-img",
    dockerInit,
    *afterTargetArgs,
]

# print(args)

_ = subprocess.call(args)
