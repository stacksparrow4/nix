{ inputs, pkgs, config, lib, ... }:

let 
  allEnvs = builtins.filter (x: (
    (lib.hasSuffix ".nix" x) &&
    (x != ./default.nix)
  )) (lib.filesystem.listFilesRecursive ./.);
in
{
  options.sprrw.useAllEnvironments = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = {
    home.packages = (if config.sprrw.useAllEnvironments then (
      builtins.concatMap (x: (import x) {
        inherit pkgs;
      }) allEnvs
    ) else []) ++ (builtins.map (
      file:
      pkgs.writeScriptBin "dev-${builtins.head (builtins.match "^(.*)\\.nix$" (builtins.baseNameOf file))}" ''
        #!${pkgs.stdenv.shell}

        if [[ -f shell.nix ]]; then
          echo "shell.nix already exists! Please remove before using this script"
          exit 1
        fi

        cat <<"EOFTHATWILLNEVERAPPEAR" > shell.nix
        let
          pkgsStable = import (fetchTarball {
            url = "https://github.com/NixOS/nixpkgs/archive/${inputs.nixpkgs-stable.rev}.tar.gz";
            sha256 = "${inputs.nixpkgs-stable.narHash}";
          }) {};
          pkgs = import (fetchTarball {
            url = "https://github.com/NixOS/nixpkgs/archive/${inputs.nixpkgs.rev}.tar.gz";
            sha256 = "${inputs.nixpkgs.narHash}";
          }) {
            overlays = [(
              ${builtins.replaceStrings ["\n"] ["\n      "] (
                lib.strings.trim (
                  builtins.concatStringsSep "\n" (builtins.tail (lib.splitString "\n" (builtins.readFile ../../../overlays.nix)))
                )
              )}
            )];
          };
        in
        pkgs.mkShell {
          buildInputs = ${
            builtins.replaceStrings ["\n"] ["\n  "] (
              lib.strings.trim (
                builtins.concatStringsSep "\n" (builtins.tail (lib.splitString "\n" (builtins.readFile file)))
              )
            )
          };
        }
        EOFTHATWILLNEVERAPPEAR

        echo "shell.nix written!"
      ''
    ) allEnvs);
  };
}
