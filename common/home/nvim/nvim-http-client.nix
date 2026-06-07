{
  pkgs ? import <nixpkgs> { },
  vimUtils ? pkgs.vimUtils,
  python3 ? pkgs.python3,
}:

let
  pythonEnv = python3.withPackages (ps: [
    ps.requests
    ps.brotli
    ps.zstandard
  ]);
in
vimUtils.buildVimPlugin {
  pname = "nvim-http-client";
  version = "0.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "stacksparrow4";
    repo = "nvim-http-client";
    rev = "0e31417476f3d8058f78d82f94b8803e8f7d3641";
    hash = "sha256-cCaOjScDC6Sgw9rP6llvyu3bswHYYhVG1wQ5xcUxpEk=";
  };

  postPatch = ''
    substituteInPlace lua/nvim-http-client/init.lua \
      --replace-fail \
        'runner = { "uv", "run" },' \
        'runner = { "${pythonEnv}/bin/python3" },'

    substituteInPlace python/send_request.py \
      --replace-fail \
        '#!/usr/bin/env -S uv run --script' \
        '#!${pythonEnv}/bin/python3'
  '';

  doCheck = false;
}
