---
name: rizin
description: Reverse engineering tool. Use for decompiling executables.
disable-model-invocation: true
---

# Rizin

## Starting a new instance

When starting a new decompilation project, create a new Rizin instance:

```bash
./start.py path/to/binary
```

This will return a socket path that can be used to run Rizin commands.


## Commands

Run a Rizin command as follows, supply the socket path from `./start.py`:

```bash
./client.py /tmp/socketname 'command'
```

## Useful commands

- `?`: Get basic help
- `afl`: List functions
- `pdg @ 0x1234`: Print Ghidra decompilation of the function at address 0x1234
- `exit`: Shut down the Rizin instance started with `./start.py`.

## Workflow for decompiling a function

1. Run `pdg` on the function to get a decompilation using Ghidra
2. Copy the code to an appropriate C/C++ source file.
3. Modify the code and clean it up. Ghidra decompilation is messy, so use the edit tool to clean it up so that it becomes as close as possible to real code.

## General guidelines

- Create a new folder for the decompilation files. For example, if you are decompiling `poc.exe`, create the folder `poc.exe.decompiled` and create files such as `poc.exe.decompiled/main.c`.
- Do not decompile commonly known/compiler generated functions unless explicitly asked. Aim to reproduce the original source code.
- If you are not sure how to do something, do not guess the command. Instead, search Rizin's command list using `?* ~searchquery`. Once an appropriate command is found, use `?` to get help for that command. Eg `afl?`

After this tool is loaded, report back with "Rizin engine ready." and nothing else.
