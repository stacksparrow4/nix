This is a NixOS repo using flakes, following the dendritic pattern: every `.nix`
file under `modules/` is a flake-parts module, and they are all imported
automatically by `import-tree` from `flake.nix`. There are no manual `imports`
lists to maintain.

## Structure

- **`modules/`**: everything. Auto-imported by `import-tree`, so a new file is
  live as soon as it exists.
  - **`modules/nixos/`**: system aspects, published as `flake.nixosModules.<name>`
  - **`modules/home/`**: home-manager aspects, published as `flake.homeModules.<name>`
  - **`modules/pkgs/`**: one module per package, each setting `perSystem.packages.<name>`
  - **`modules/hosts/`**: one directory per host; builds `flake.nixosConfigurations.<name>`
    (or `flake.homeConfigurations.<name>`) from a list of aspects
  - **`modules/lib/`**: helpers exposed as `perSystem` module args (e.g. `mkSandbox`)
  - **`modules/systems.nix`**: supported systems and the `pkgs` / `pkgs-unstable` instances
  - **`modules/home-manager.nix`**: loads home-manager's flake-parts module, which
    declares `flake.homeModules` and `flake.homeConfigurations`

## Conventions

- **Importing is enabling.** Aspects have no `enable` flags; a host gets an
  aspect by importing it. Options are only for *data* (e.g. `sprrw.ai.llama.models`),
  not for on/off switches.
- **Names are flat and path-derived** within a class: `modules/home/sec/windows.nix`
  becomes `flake.homeModules.sec-windows`.
- **If it only needs `pkgs`, it's a package** (`modules/pkgs/`). If it reads
  host/home config, it's an aspect.
- **Sandboxed tools are packages.** `mkSandbox` lives in `modules/lib/mksandbox.nix`
  as a `perSystem` arg; the sandboxed wrapper *is* the package (e.g. `packages.nxc`).
  These are Linux-only, since the `sandbox` helper is bubblewrap-based.
- **No `specialArgs` pass-thru.** Aspect files that need per-system values
  (`self'`, `pkgs-unstable`) wrap their module in `moduleWithSystem`; everything
  else is captured lexically from the flake-parts module arguments.

## Transitional

`common/` and `hosts/` still hold the pre-dendritic home-manager tree, reached
via `home-manager.users.sprrw` in the host modules. Converting it to
`flake.homeModules` is the remaining work; once done, both directories and the
`home-manager.extraSpecialArgs` blocks in `modules/hosts/*` go away.
