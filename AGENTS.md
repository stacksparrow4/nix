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
  - **`modules/lib/`**: helpers exposed as `perSystem` module args (e.g. `mkSandbox`,
    `fetchHF`)
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
- **Aggregates are just `imports` lists.** `sec`, `term`, `programming`, `gui`,
  `linux` and `ai` are aspects whose body reads `config.flake.homeModules`.
  Anything a host wants to opt into separately (`sec-gui`, `programming-sage`,
  `ai-llama`, …) stays out of its aggregate.
- **Cross-cutting data options live in `base`.** `sprrw.nixosRepoPath` and
  `sprrw.term.shellExtra` are read and written by aspects all over the tree, and
  every host imports `base`, so that is where they are declared.
- **`_`-prefixed paths are invisible to `import-tree`.** Use that for files that
  are *not* flake-parts modules: parameterised function files
  (`modules/home/ai/pi/_pi-exec.nix`) and the nested standalone flake
  (`modules/hosts/_macbook-vm/`).
- **`mkOutOfStoreSymlink` targets are repo-relative strings.** They are built
  from `${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/…`, so moving
  an asset breaks the symlink at *activation* time, not at eval time. Grep for
  `nixosRepoPath}/` after moving anything.
