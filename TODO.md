- Package the following
    - opengrep
- Nvim prettier formatter for GraphQL
- With docker mounts, if the dir doesn't exist docker will create it. But this means its created as root with bad dir ownership. Eg. jwt_tool config
    - Make a more standardised way of doing this
- Investigate possibly using bubblewrap instead of docker? (Does it provide performance benefit?) What about using a statically compiled sudo? (Nasm?)
- Sandbox browser properly
    - https://github.com/NixOS/nixpkgs/blob/b6a8526db03f735b89dd5ff348f53f752e7ddc8e/pkgs/applications/networking/browsers/chromium/common.nix#L671


Vimium custom key mappings by default?
```
unmapAll
map j scrollDown
map k scrollUp
map f LinkHints.activateMode
```
