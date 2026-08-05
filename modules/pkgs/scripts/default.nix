{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      shellNixCreator =
        { scriptName, mkShellCmd }:
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
        '';
    in
    {
      packages = {
        mkpythonenv = shellNixCreator {
          scriptName = "mkpythonenv";
          mkShellCmd = ''
            pkgs.mkShellNoCC {
              packages = (with pkgs; [
                python312
              ]) ++ (with pkgs.python312Packages; [
              ]);
            }
          '';
        };

        mkwindowsenv = shellNixCreator {
          scriptName = "mkwindowsenv";
          mkShellCmd = ''
            pkgs.mkShell {
              buildInputs = with pkgs.pkgsCross.mingwW64.buildPackages; [
                gcc
                clang-tools
                cmake
              ];
            }
          '';
        };

        # TODO: remove
        windows-yaml = pkgs.writeShellScriptBin "windows-yaml.sh" (builtins.readFile ./windows-yaml.sh);

        sshp = pkgs.writeShellApplication {
          name = "sshp";
          text = ''
            sshpass -p "$2" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$1" "''${@:3}"
          '';
        };
      };
    };
}
