{ pkgs, inputs, scriptName, mkShellCmd }:

pkgs.writeShellScriptBin scriptName ''
  #!${pkgs.stdenv.shell}

  if [[ -f shell.nix ]]; then
    echo "shell.nix already exists! Please remove before using this script"
    exit 1
  fi

  cat <<"SOMEEOFTHATWONTEXIST" > shell.nix
  let
    pkgs = import (fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/${inputs.nixpkgs.rev}.tar.gz";
      sha256 = "${inputs.nixpkgs.narHash}";
    }) {};
  in
  ${mkShellCmd}
  SOMEEOFTHATWONTEXIST

  echo "Written shell.nix!"
''
