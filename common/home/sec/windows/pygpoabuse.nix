{ lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.pygpoabuse.enable = lib.mkEnableOption "pygpoabuse";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.pygpoabuse.enable {
    home.packages = [(
      pkgs.stdenv.mkDerivation {
        name = "pygpoabuse";

        src = pkgs.fetchFromGitHub {
          owner = "Hackndo";
          repo = "pyGPOAbuse";
          rev = "63567b8807b6c47e207e9f04071aa3f756cc27a1";
          hash = "sha256-7u4nnoHStkl2xT1Bk5jHj0L80gaERkF+Pmxh+j/o1vs=";
        };

        pythonWithPkgs = pkgs.python3.withPackages(ps: with ps; [
          msldap
          impacket
        ]);

        buildPhase = ''
          mkdir -p $out/bin

          echo '#!${pkgs.stdenv.shell}' > $out/bin/pygpoabuse.py
          cp -r . $out/src
          echo "$pythonWithPkgs/bin/python3 $out/src/pygpoabuse.py \"\$@\"" >> $out/bin/pygpoabuse.py

          chmod +x $out/bin/pygpoabuse.py
        '';

        dontInstall = true;
      }
    )];
  };
}
