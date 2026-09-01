{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      pwndbgFlake = builtins.getFlake "github:pwndbg/pwndbg/bea36c8e08b428e3812470097e6e7c8e11f0be9d";
      pwndbg = pwndbgFlake.packages.x86_64-linux.pwndbg;
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        inherit pwndbg;

        pwntools-env = pkgs.buildEnv {
          name = "pwntools-env";
          paths = [
            (pkgs.runCommand "pwntools-gdb" { } ''
              mkdir -p $out/bin
              ln -s ${pwndbg}/bin/pwndbg $out/bin/pwntools-gdb
            '')
            pkgs.pwntools
          ];
          ignoreCollisions = true;
        };
      };
    };
}
