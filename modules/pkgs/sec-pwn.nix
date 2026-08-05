# Sandboxed wrappers plus the pwntools env for binary exploitation.
{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    let
      # TODO: make this a proper flake input instead of an inline getFlake.
      pwndbgFlake = builtins.getFlake "github:pwndbg/pwndbg/bea36c8e08b428e3812470097e6e7c8e11f0be9d";
      pwndbg = pwndbgFlake.packages.x86_64-linux.pwndbg;

      cwdOnly =
        name: prog:
        mkSandbox {
          inherit name prog;
          shareCwd = true;
        };
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

        pwninit = cwdOnly "pwninit" "${pkgs.pwninit}/bin/pwninit";
        ropr = cwdOnly "ropr" "${pkgs.ropr}/bin/ropr";
        ROPgadget = cwdOnly "ROPgadget" "${pkgs.ropgadget}/bin/ROPgadget";
      };
    };
}
