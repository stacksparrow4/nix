# The mingw cross gccs, wrapped so that the cross toolchain's environment is
# sourced when the binaries are invoked outside of a nix shell.
{
  perSystem =
    { pkgs, ... }:
    let
      buildWindowsGccWrapper =
        winGcc:
        let
          winGccShellEnv = pkgs.stdenv.mkDerivation {
            name = "win-gcc-shell-env";
            buildInputs = [ winGcc ];

            phases = [ "buildPhase" ];

            buildPhase = ''
              export >> "$out"
            '';
          };
        in
        pkgs.runCommand "mingw-env-gcc" { } ''
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
    in
    {
      packages = {
        mingw32-gcc = buildWindowsGccWrapper pkgs.pkgsCross.mingw32.buildPackages.gcc;
        mingwW64-gcc = buildWindowsGccWrapper pkgs.pkgsCross.mingwW64.buildPackages.gcc;
      };
    };
}
