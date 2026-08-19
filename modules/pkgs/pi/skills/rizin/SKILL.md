---
name: rizin
description: Reverse engineering tool. Use for decompiling executables.
disable-model-invocation: true
---

# Example Rizin commands

## Argument reference

- `-A`: Analysis. Use when a binary argument is specified.
- `-q`: Quiet mode.
- `-c`: Run command.

## List functions

```bash
rizin -A -q -c 'afl' path/to/binary
```

## Ghidra decompile function at address 0x1234

```bash
rizin -A -q -c 'pdg @ 0x1234' path/to/binary
```

## List available Rizin commands

```bash
rizin -q -c '?*'
```

# General guidelines

- When writing a C/C++ file, create a new file per function. Write global variables in another file, separate to the function.
- Do not decompile commonly known/compiler generated functions unless explicitly asked. Aim to reproduce the original source code.

After this tool is loaded, report back with "Rizin loaded." and nothing else.
