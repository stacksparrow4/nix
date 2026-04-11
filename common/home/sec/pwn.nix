{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.sec.pwn.enable = lib.mkEnableOption "pwn";
  };

  config = lib.mkIf config.sprrw.sec.pwn.enable {
    home.packages =
      let
        pwndbgFlake = builtins.getFlake "github:pwndbg/pwndbg/bea36c8e08b428e3812470097e6e7c8e11f0be9d";
        pwndbg = pwndbgFlake.packages.x86_64-linux.pwndbg;
      in
      with pkgs;
      [
        pwndbg
        gdb
        lldb
        (pkgs.buildEnv {
          name = "pwntools-env";
          paths = [
            (pkgs.runCommand "pwntools-gdb" { } ''
              mkdir -p $out/bin
              ln -s ${pwndbg}/bin/pwndbg $out/bin/pwntools-gdb
            '')
            pwntools
          ];
          ignoreCollisions = true;
        })
        patchelf
        (config.sprrw.sandbox.create {
          name = "pwninit";
          shareCwd = true;
          prog = "${pwninit}/bin/pwninit";
        })
        (config.sprrw.sandbox.create {
          name = "ropr";
          shareCwd = true;
          prog = "${ropr}/bin/ropr";
        })
        (config.sprrw.sandbox.create {
          name = "ROPgadget";
          shareCwd = true;
          prog = "${ropgadget}/bin/ROPgadget";
        })
      ];
  };
}
