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

## General guidelines

- When writing a C/C++ file, create a new file per function. Write global variables in another file, separate to the function.
- Do not decompile commonly known/compiler generated functions unless explicitly asked. Aim to reproduce the original source code.
- If you are not sure how to do something, do not guess the command. Instead, search Rizin's command list using `?* ~searchquery`. Once an appropriate command is found, use `?` to get help for that command. Eg `afl?`

After this tool is loaded, report back with "Rizin engine ready." and nothing else.
