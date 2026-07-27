# AGENTS.md

## Project overview

`oob` is a small Rust CLI that acts as a thin wrapper around
[`interactsh-client`](https://github.com/projectdiscovery/interactsh). It runs
interactsh in JSON mode, parses the JSON-lines interaction stream, and
re-displays only a focused subset of each interaction:

- the interactsh-generated URL (e.g. `blah.oast.live`)
- the date/time of each interaction (colorized per-timestamp)
- the interaction type (DNS, HTTP, SMTP, ...)
- for HTTP/HTTPS, the full raw HTTP **request** (never the response)

All other interactsh output (banner, INF logs, raw responses) is suppressed.

## Layout

- `src/main.rs` — the entire implementation (single file).
- `Cargo.toml` — package manifest and dependencies.
- `default.nix` — Nix package build (via [crane](https://github.com/ipetkov/crane)).

## Build / run / test

```sh
cargo build              # debug build
cargo build --release    # release build (opt-level = 2)
cargo run -- [flags]     # run; flags after `--` are forwarded to interactsh
cargo fmt                # format
cargo clippy             # lint
cargo test               # run tests (none yet)
```

Nix build:

```sh
nix build .#oob          # builds via crane (run from the repo root)
```

Toolchain in use: cargo/rustc 1.91 (edition 2021).

## Runtime requirements

- `interactsh-client` must be installed and on `PATH` (invoked as the bare name
  `interactsh`). The wrapper always forces `-json`, `-ps`, and `-psf <tmpfile>`,
  then appends any user-supplied flags.

## Conventions

- Keep the output minimal and focused — do not surface data the tool
  intentionally hides (raw responses, remote addresses, etc.).
- ANSI escape codes are used directly for coloring; keep new colors readable.
- Prefer the standard library; current deps are `serde`, `serde_json`, and
  `chrono` only. Avoid adding dependencies unless necessary.
- Run `cargo fmt` and `cargo clippy` before finishing changes.

## Notes for changes

- The build uses crane, which reads `Cargo.lock` to vendor dependencies. There
  is no `cargoHash` to maintain — just keep `Cargo.lock` in sync with
  `Cargo.toml` (run `cargo build`/`cargo update` after changing deps).
- Dependencies are built separately (`buildDepsOnly`) and cached, so only the
  crate itself is rebuilt when `src/` changes.
- `default.nix` receives the `crane` flake input via the top-level flake; it
  cannot be built standalone with plain `nix-build` anymore — use
  `nix build .#oob` from the repo root.
- The `Interaction` struct in `src/main.rs` deliberately ignores most
  interactsh fields; only add fields when they are actually displayed.
