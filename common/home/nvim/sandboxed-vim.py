#!/usr/bin/env python3

import sys
import subprocess
import os

endDockerArgsInd = sys.argv.index("ENDDOCKERARGS")

runDocker = sys.argv[1]
additionalDockerArgs = sys.argv[2:endDockerArgsInd]
vimPath = sys.argv[endDockerArgsInd + 1]
vimArgs = sys.argv[endDockerArgsInd + 2 :]

if len(vimArgs) == 1 and vimArgs[0].startswith("/"):
    arg = vimArgs[0]
    if os.path.isdir(arg):
        shareDir = arg
        shareFile = "."
    else:
        shareDir = os.path.dirname(arg)
        shareFile = os.path.basename(arg)

    exit(
        subprocess.call(
            [
                runDocker,
                "-it",
                "-w",
                "/pwd",
                "-v",
                f"{shareDir}:/pwd",
                *additionalDockerArgs,
                "DOCKERIMG",
                vimPath,
                shareFile,
            ]
        )
    )

exit(
    subprocess.call(
        [
            runDocker,
            "-it",
            "-w",
            "/pwd",
            "-v",
            f"{os.getcwd()}:/pwd",
            *additionalDockerArgs,
            "DOCKERIMG",
            vimPath,
            *vimArgs,
        ]
    )
)
