- [ ] Sandbox browser properly
    - https://github.com/NixOS/nixpkgs/blob/b6a8526db03f735b89dd5ff348f53f752e7ddc8e/pkgs/applications/networking/browsers/chromium/common.nix#L671
- [ ] Somehow evaluate every package that is used and diff that in diff-protected
    - Looks like this could potentially be done using `nix build --dry-build -vvv` and grepping for nixpkgs


nix build --dry-run -vvv .#nixosConfigurations.nest01.config.system.build.toplevel
nix eval --raw --impure --expr '(builtins.getFlake "path://'$(pwd)'").inputs.nixpkgs.outPath'

nix build --dry-run -vvv .#nixosConfigurations.nest01.config.system.build.toplevel 2>&1 | grep -F "$(nix eval --raw --impure --expr '(builtins.getFlake "path://'$(pwd)'").inputs.nixpkgs.outPath')" | grep -F ".nix"

Takes around 27 seconds... is this too long?
