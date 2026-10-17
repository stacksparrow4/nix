This is a NixOS repo using flakes and the dendritic pattern. Flake parts modules exist under `modules/`, which are imported automatically using `import-tree` in `flake.nix`.

Recursive greps may time out due to the existence of rust projects with large target directories, so be sure to exclude those.

Do not build Nix derivations (unless explicitly asked) as nix may not be available/run slowly in the sandbox you are in. Instead, ask the user to build and test.
