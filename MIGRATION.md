# Dendritic migration — step ④ plan (home-manager tree)

Steps ①–③ are done and verified (see "Verification" below). What remains is
converting `common/home/` (~70 nix files, 64 non-nix assets) into
`flake.homeModules.*`, rewriting the three host entry points, and deleting the
transitional scaffolding.

This step is **atomic**: hosts reach the aspect tree via `common/home/default.nix`
today, and a half-converted tree would have some aspects reachable only from
flake scope and some only from the host module. So the whole table below, the
host import lists, and the cleanup land together.

## Conventions recap (decisions already made)

- Importing is enabling. No `enable` flags; options only carry *data*.
- Names are flat and path-derived within the class: `sec/windows/netexec.nix`
  → `flake.homeModules.sec-windows-netexec`.
- Files needing `self'` / `pkgs-unstable` wrap their module in `moduleWithSystem`.
- Aggregates (`sec`, `term`, …) are modules whose only job is an `imports` list
  read from `config.flake.homeModules`.

## 1. Aspect map

`modules/home/<file>` → `flake.homeModules.<name>`. "Agg" = aggregate (imports
only). "MWS" = needs `moduleWithSystem` because it reads `self'`/`pkgs-unstable`.

| source | name | MWS | notes |
| --- | --- | --- | --- |
| `default.nix` | `base` | | keeps `sprrw.nixosRepoPath` option, `nixpkgs/config.nix`, `stateVersion`, `news.display`; drop the `nix.extraOptions` darwin guard in favour of a linux-only aspect |
| `general.nix` | `general` | ✓ | drop `enable` (was `default = true`); the two Linux-only wrappers move to `general-linux` |
| — | `general-linux` | ✓ | `nodemon`, `dumbpipe` (decision ⑪) |
| `misc.nix` | `misc` | ✓ | |
| `payloads.nix` | `payloads` | | |
| `sprrw.nix` | `sprrw-cli` | ✓ | `self'.packages.sprrw` |
| `sandboxing.nix` | `sandbox` | ✓ | `mkSandbox` def is **already gone** (now `modules/lib/mksandbox.nix`); what remains is `sandbox` pkg + `build-vm`/`vm-enter` (config-reading, decision ⑭) + `shellExtra` aliases |
| `scripts/default.nix` | `scripts` | ✓ | |
| `sec/default.nix` | `sec` | Agg | the 12 headless-safe aspects (decision ⑰) |
| `sec/gui.nix` | `sec-gui` | ✓ | binaryninja, ghidra, wireshark **+ caido** (decision ⑰) |
| `sec/caido.nix` | — | | **merged into `sec-gui`**; file goes away |
| `sec/cracking.nix` | `sec-cracking` | ✓ | |
| `sec/forensics.nix` | `sec-forensics` | ✓ | |
| `sec/jwttool.nix` | `sec-jwttool` | ✓ | |
| `sec/metasploit.nix` | `sec-metasploit` | ✓ | |
| `sec/mobile.nix` | `sec-mobile` | ✓ | |
| `sec/pwn.nix` | `sec-pwn` | ✓ | |
| `sec/pwnproxy/default.nix` | `sec-pwnproxy` | ✓ | keeps data option `sprrw.sec.pwnproxy.config`; asset `tools/` |
| `sec/reversing.nix` | `sec-reversing` | ✓ | |
| `sec/scanning.nix` | `sec-scanning` | ✓ | |
| `sec/snmp.nix` | `sec-snmp` | ✓ | |
| `sec/web.nix` | `sec-web` | ✓ | |
| `sec/windows/default.nix` | `sec-windows` | Agg+✓ | aggregate **and** its own packages; consider splitting the package list into `sec-windows-tools` |
| `sec/windows/{bloodhoundpy,gcc,impacket,kerbrute,krbrelayx,netexec,pygpoabuse,rusthound}.nix` | `sec-windows-<x>` | ✓ | each is now a one-line package list; **candidate for merging into `sec-windows`** (dendritic README warns against name proliferation) |
| `term/default.nix` | `term` | Agg | keeps data options `sprrw.term.shellExtra` (accumulated by several aspects) |
| `term/bash.nix` | `term-bash` | | keeps `ps1` option |
| `term/zshrc.nix` | `term-zshrc` | | reads `shellExtra` |
| `term/foot/default.nix` | `term-foot` | | keeps `installTerminfo`; asset `foot.ini` |
| `term/navi/default.nix` | `term-navi` | | asset `cheats/` |
| `term/tmux/default.nix` | `term-tmux` | | keeps `defaultTerm` |
| `term/yazi.nix` | `term-yazi` | | portable part |
| `linux/yazi.nix` | `term-yazi-linux` | | the `xdg.mimeApps` + openers split (decision ⑨) |
| `programming/default.nix` | `programming` | Agg | |
| `programming/<lang>.nix` ×17 | `programming-<lang>` | `sage` ✓ | `c`, `databases`, `dotnet`, `git`, `go`, `java`, `kubernetes`, `lua`, `node`, `php`, `ruby`, `rust`, `sage`, `typst`, `xml`, `zig` |
| `gui/default.nix` | `gui` | Agg+✓ | `pkgs-unstable.flameshot` |
| `gui/browsers.nix` | `gui-browsers` | ✓ | `pkgs-unstable` |
| `gui/obs.nix` | `gui-obs` | | |
| `gui/obs-cli-tool/default.nix` | (package) | | **move to `modules/pkgs/obs-cli-tool/`** — self-contained node tool (decision ⑭) |
| `gui/emoji-picker.nix` | `gui-emoji-picker` | ✓ | pkg already extracted |
| `gui/lmms.nix` | `gui-lmms` | ✓ | pkg already extracted |
| `gui/signal.nix` | `gui-signal` | ✓ | pkg already extracted |
| `linux/default.nix` | `linux` | Agg | |
| `linux/desktop-entries.nix` | `linux-desktop-entries` | | |
| `linux/rofi.nix` | `linux-rofi` | | |
| `linux/sway.nix` | `linux-sway` | ✓ | asset `sway/config` |
| `linux/noctalia/default.nix` | `linux-noctalia` | ✓ | imports `inputs.noctalia.homeModules.default`; asset `main.toml` |
| `linux/term.nix` | `linux-term` | ✓ | |
| `linux/yubikey.nix` | `linux-yubikey` | | |
| `nvim/default.nix` | `nvim` | | keeps `sandboxed`, `additionalSharedFolders`; asset `lua/` |
| `ai/default.nix` | `ai` | Agg+✓ | |
| `ai/llama-cpp.nix` | `ai-llama` | ✓ | keeps `context`, `models` data options |
| `ai/pi/default.nix` | `ai-pi` | ✓ | keeps `extraModels`, `execModel`; assets `skills/`, `extensions/`, `prompts/` |
| `ai/pi/{pi-exec,pi-convert}.nix` | — | | stay as **function files** called by `ai-pi` (parameterised by config, decision ⑭) |
| `ai/fetch-hf.nix` | — | | **move to `modules/lib/fetchhf.nix`** as `perSystem._module.args.fetchHF`, like `mkSandbox`; `nest01`'s model list then needs `moduleWithSystem` |

## 2. Assets to move (64 non-nix files)

`common/home/X` → `modules/home/X`, keeping each next to its aspect:
`ai/pi/{extensions,prompts,skills}`, `gui/obs-cli-tool/{index.js,package*.json}`
(→ `modules/pkgs/obs-cli-tool/`), `linux/noctalia/main.toml`,
`linux/sway/config`, `nvim/lua/**` (17 files), `sec/pwnproxy/tools/ffuf`,
`term/foot/foot.ini`, `term/navi/cheats/*` (13 files), `term/tmux/*`.

`linux/sway/alternating_layouts.py` is already moved (now in
`modules/pkgs/alternating-layouts/`).

### ⚠ Path strings that must be rewritten

`mkOutOfStoreSymlink` builds **repo-relative strings**, so these break silently
(dangling symlink at activation, not an eval error) unless updated:

| in | current suffix | becomes |
| --- | --- | --- |
| `ai/pi/default.nix` | `/common/home/ai/pi/{skills,extensions,prompts}` | `/modules/home/ai/pi/…` |
| `linux/noctalia/default.nix` | `/common/home/linux/noctalia/main.toml` | `/modules/home/linux/noctalia/main.toml` |
| `linux/sway.nix` | `/common/home/linux/sway/config` | `/modules/home/linux/sway/config` |
| `term/foot/default.nix` | `/common/home/term/foot/foot.ini` | `/modules/home/term/foot/foot.ini` |
| `term/navi/default.nix` | `/common/home/term/navi/cheats` | `/modules/home/term/navi/cheats` |
| `hosts/nest01/home/*` | `/hosts/nest01/home/{sway,kanshi,ssh}.config`, `noctalia.toml` | `/modules/hosts/nest01/…` (files already copied there) |

## 3. Host import lists

```nix
# nest01
with config.flake.homeModules; [
  base general general-linux misc payloads sprrw-cli sandbox scripts
  term term-yazi-linux linux nvim programming programming-sage
  sec sec-gui gui gui-signal gui-lmms ai ai-llama ai-pi
]
# vm  (no `linux` aggregate, only linux-term; no gui; sec without sec-gui)
with config.flake.homeModules; [
  base general general-linux misc sprrw-cli scripts
  term term-yazi-linux linux-term nvim programming sec ai
]
# dan  (darwin: no sandboxed tools, no linux aspects)
with config.flake.homeModules; [
  base general scripts nvim
  term-zshrc term-yazi term-tmux
  programming-git programming-kubernetes
]
```

Per-host *data* stays in the host file: `nvim.sandboxed = false` and
`term.tmux.defaultTerm = "ghostty"` (dan), `ai.llama.models` /
`ai.pi.execModel` (nest01), `home.username`/`homeDirectory`, `.background-image`,
the `hosts/nest01` config symlinks.

## 4. Open triage (needs a decision when reached)

1. `vm` sets `sprrw.ai.enable = true` but nothing else under `ai` — with `ai`
   now being just the `bx` wrapper + aggregate, confirm `vm` wants it.
2. `vm` enables `linux.term` without `linux`. Keep that split, or give `vm` the
   full `linux` aggregate?
3. `dan` currently gets `general` (default `true`) — includes an `ssh` shim and
   ~30 CLI tools. Intentional on macOS?
4. `sec-windows-*`: 8 aspects that are now one-line package lists. Merge into
   `sec-windows` (fewer names) or keep individually importable?
5. `term/default.nix`'s `shellExtra` is written by `sandboxing.nix`, `term`, and
   others. Keep as an accumulating option (recommended) or restructure?
6. Dead code found: `sprrw.font.mainFontName` / `mainFontMonoName` are set but
   never read (see `modules/nixos/fonts.nix`). Delete?
7. `sec/pwn.nix` uses `builtins.getFlake "github:pwndbg/pwndbg/<rev>"` (now in
   `modules/pkgs/sec-pwn.nix`). Promote to a real flake input, per `TODO.md`.

## 5. Mechanical recipe per file

```nix
# before: common/home/sec/cracking.nix
{ config, lib, pkgs, self', ... }:
{
  options.sprrw.sec.cracking.enable = lib.mkEnableOption "cracking";
  config = lib.mkIf config.sprrw.sec.cracking.enable { home.packages = [ ... ]; };
}

# after: modules/home/sec/cracking.nix
{ moduleWithSystem, ... }:
{
  flake.homeModules.sec-cracking = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    { home.packages = [ pkgs.hashcat pkgs.john self'.packages.hydra ]; }
  );
}
```

Rules: delete `options.*.enable` + the `lib.mkIf` wrapper (keep data options),
wrap in `moduleWithSystem` only if `self'`/`pkgs-unstable` is used, take `inputs`
from the outer flake-parts args instead of a module arg.

## 6. Cleanup once step ④ lands

- delete `common/` and `hosts/`
- delete the `home-manager.extraSpecialArgs` blocks in `modules/hosts/*`
- delete the "Transitional" section of `AGENTS.md` and this file

## Verification

Baseline is the pre-migration tree. Compare *profile contents by derivation
name* (order-insensitive), not drv hashes, since composition-by-import changes
`home.packages` ordering:

```bash
nix eval .#nixosConfigurations.nest01.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nest01.config.home-manager.users.sprrw.home.activationPackage.drvPath
nix eval .#nixosConfigurations.vm.config.home-manager.users.sprrw.home.activationPackage.drvPath
nix eval .#homeConfigurations.dan.activationPackage.drvPath
nix derivation show -r <drv> | jq …   # diff the home-manager-path input set
```

Known-good deltas after steps ①–③: `+lndir` (from the impacket `symlinkJoin`),
`−nodemon`/`−dumbpipe` on `dan`, all 108 sandbox wrappers rebuilt for
`${sandbox}/bin/sandbox`, and a reordering (same set) inside `system-path`.
Expected *additional* delta after step ④: `home.packages` ordering everywhere.
