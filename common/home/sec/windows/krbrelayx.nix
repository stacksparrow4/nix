{ pkgs, lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.krbrelayx.enable = lib.mkEnableOption "krbrelayx";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.stdenv.hostPlatform.system; };
  in lib.mkIf config.sprrw.sec.windows.krbrelayx.enable {
    home.packages = [(
      pkgs.stdenv.mkDerivation {
          name = "krbrelayx";

          src = pkgs.fetchFromGitHub {
            owner = "dirkjanm";
            repo = "krbrelayx";
            rev = "aef69a7e4d2623b2db2094d9331b2b07817fc7a4";
            hash = "sha256-rcDa6g0HNjrM/XdXOF22iURA9euJbSahGKlFr5R7I/U=";
          };

          pythonWithPkgs = pkgs.python311.withPackages(ps: with ps; [
            impacket
            ldap3
            dnspython
          ]);

          buildPhase = ''
            mkdir -p $out/bin

            for script in $src/*.py; do
              outpath="$out/bin/$(basename -s .py "$script")"
              echo "#!${pkgs.stdenv.shell}" > "$outpath"
              echo "$pythonWithPkgs/bin/python3 $script \"\$@\"" >> "$outpath"

              chmod +x "$outpath"
            done
          '';

          dontInstall = true;
        }
    )];
  };
}
