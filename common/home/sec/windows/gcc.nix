{ config, lib, ... }@inputs:

{
  options = {
    sprrw.sec.windows.gcc.enable = lib.mkEnableOption "gcc";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.gcc.enable {
    home.packages = let
      buildWindowsGccWrapper = winGcc:
      let
        winGccShellEnv = pkgs.stdenv.mkDerivation {
          name = "win-gcc-shell-env";
          buildInputs = [winGcc];

          phases = [ "buildPhase" ];

          buildPhase = ''
            export >> "$out"
          '';
        };
      in
        pkgs.runCommand "mingw-env-gcc" {} ''
          mkdir -p "$out/bin"

          for binfile in $(cd ${winGcc.out}/bin; echo *); do
            cat > "$out/bin/$binfile" <<EOF
          #!${pkgs.stdenv.shell}

          source ${winGccShellEnv}
          
          $binfile "\$@"
          EOF
            chmod +x "$out/bin/$binfile"
          done
        '';
    in [
      (buildWindowsGccWrapper pkgs.pkgsCross.mingw32.buildPackages.gcc)
      (buildWindowsGccWrapper pkgs.pkgsCross.mingwW64.buildPackages.gcc)
    ];
  };
}
