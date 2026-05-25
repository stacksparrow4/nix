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
- `?* ~sometext`: Grep all help pages (`?*`) for "sometext"
- `afl`: List functions
- `afl ~main`: Grep the function list for "main"
- `pdf @ main`: Print disassembled function with name "main"
- `pdf @ 1234`: Print disassembled function at address 1234
- `pdg @ main`: Print Ghidra decompilation of function "main"
- `exit`: Shut down the Rizin instance started with `./start.py`.

## General guidelines

- Create a new folder for the decompilation files. For example, if you are decompiling `poc.exe`, create the folder `poc.exe.decompiled` and create files such as `poc.exe.decompiled/main.c`.
- Do not decompile commonly known/compiler generated functions unless explicitly asked. Aim to reproduce the original source code.

After this tool is loaded, report back with "Rizin engine ready." and nothing else.
