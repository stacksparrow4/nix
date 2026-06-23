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
- `default.nix` — Nix package build (`rustPlatform.buildRustPackage`).

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
nix-build                # builds via default.nix
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

- If you change the `default.nix` source or dependencies, the `cargoHash` in
  `default.nix` will likely need updating.
- The `Interaction` struct in `src/main.rs` deliberately ignores most
  interactsh fields; only add fields when they are actually displayed.
