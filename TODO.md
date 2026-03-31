- Automatically disable sandboxing if already inside a sandbox
- Override xterm-256color terminfo with terminal emulator terminfo so I don't have to override TERM all the time
- Package the following
    - opengrep
- Nvim prettier formatter for GraphQL
- With docker mounts, if the dir doesn't exist docker will create it. But this means its created as root with bad dir ownership. Eg. jwt_tool config
    - Make a more standardised way of doing this

Vimium custom key mappings:
```
unmapAll
map j scrollDown
map k scrollUp
map f LinkHints.activateMode
```
