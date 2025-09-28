{ config, lib, pkgs, ... }:

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
      with pkgs; [
        pwndbg
        (pkgs.buildEnv {
          name = "pwntools-env";
          paths = [
            (pkgs.runCommand "pwntools-gdb" {} ''
              mkdir -p $out/bin
              ln -s ${pwndbg}/bin/pwndbg $out/bin/pwntools-gdb
            '')
            pwntools
          ];
          ignoreCollisions = true;
        })
        patchelf
        pwninit
      ];
  };
}
