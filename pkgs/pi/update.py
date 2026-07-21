#!/usr/bin/env python3
"""Update pi-coding-agent to a given (or the latest) release, refreshing all
three fixed-output hashes in default.nix:

  - src         (fetchFromGitHub)
  - npmDeps     (fetchNpmDeps)
  - piAiTarball (fetchurl of the published @earendil-works/pi-ai npm tarball)

Usage: ./update.py [VERSION]
  VERSION defaults to the latest GitHub release tag (leading "v" optional).
"""
import os
import re
import subprocess
import sys
import urllib.request

OWNER = "earendil-works"
REPO = "pi"
NIXFILE = os.path.join(os.path.dirname(os.path.realpath(__file__)), "default.nix")
PKGS = "import <nixpkgs-unstable> { }"


def latest_version() -> str:
    print("Fetching latest release tag...", file=sys.stderr)
    url = f"https://github.com/{OWNER}/{REPO}/releases.atom"
    with urllib.request.urlopen(url) as resp:
        feed = resp.read().decode()
    m = re.search(r"releases/tag/v([0-9][^\"<]*)", feed)
    if not m:
        sys.exit("Could not determine latest version")
    return m.group(1)


def prefetch_sri(expr: str) -> str:
    """Realise an FOD built with a fake hash and read back the real SRI hash."""
    out = subprocess.run(
        ["nix-build", "--no-out-link", "--expr", expr],
        capture_output=True, text=True,
    ).stderr
    m = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", out)
    if not m:
        sys.exit(f"Failed to compute hash. nix-build output:\n{out}")
    return m.group(1)


def replace_hash(text: str, anchor: str, newhash: str) -> str:
    """Replace the `hash = "...";` value on the line following `anchor`."""
    pattern = re.compile(
        r'(' + re.escape(anchor) + r'\s*\n\s*hash = ")[^"]*',
    )
    new_text, n = pattern.subn(lambda mo: mo.group(1) + newhash, text, count=1)
    if n != 1:
        sys.exit(f"Anchor not found (or matched {n} times): {anchor!r}")
    return new_text


def main() -> None:
    version = sys.argv[1].lstrip("v") if len(sys.argv) > 1 else latest_version()
    print(f"Target version: {version}")

    with open(NIXFILE) as f:
        text = f.read()

    # 1. version
    text, n = re.subn(r'(?m)^(  version = ")[^"]+(";)',
                      rf'\g<1>{version}\g<2>', text)
    if n != 1:
        sys.exit("Could not find version line")

    # 2. src (fetchFromGitHub)
    print("Computing src hash...", file=sys.stderr)
    src_hash = prefetch_sri(
        f'let p = {PKGS}; in p.fetchFromGitHub {{ '
        f'owner = "{OWNER}"; repo = "{REPO}"; rev = "v{version}"; '
        f'hash = p.lib.fakeHash; }}'
    )
    text = replace_hash(text, 'rev = "v${version}";', src_hash)
    print(f"  src         = {src_hash}")

    # 3. piAiTarball (fetchurl)
    print("Computing piAiTarball hash...", file=sys.stderr)
    tarball_hash = prefetch_sri(
        f'let p = {PKGS}; in p.fetchurl {{ '
        f'url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-{version}.tgz"; '
        f'hash = p.lib.fakeHash; }}'
    )
    text = replace_hash(text, 'pi-ai-${version}.tgz";', tarball_hash)
    print(f"  piAiTarball = {tarball_hash}")

    # 4. npmDeps (fetchNpmDeps) — needs the resolved src
    print("Computing npmDeps hash...", file=sys.stderr)
    npm_hash = prefetch_sri(
        f'let p = {PKGS}; '
        f'src = p.fetchFromGitHub {{ '
        f'owner = "{OWNER}"; repo = "{REPO}"; rev = "v{version}"; hash = "{src_hash}"; }}; '
        f'in p.fetchNpmDeps {{ name = "pi-mono-{version}-npm-deps"; inherit src; '
        f'hash = p.lib.fakeHash; }}'
    )
    text = replace_hash(text, 'inherit src;', npm_hash)
    print(f"  npmDeps     = {npm_hash}")

    with open(NIXFILE, "w") as f:
        f.write(text)
    print(f"Done. default.nix updated to {version}.")


if __name__ == "__main__":
    main()
