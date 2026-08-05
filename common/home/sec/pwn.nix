{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.pwn.enable = lib.mkEnableOption "pwn";
  };

  config = lib.mkIf config.sprrw.sec.pwn.enable {
    home.packages = [
      self'.packages.pwndbg
      pkgs.gdb
      pkgs.lldb
      self'.packages.pwntools-env
      pkgs.patchelf
      self'.packages.pwninit
      self'.packages.ropr
      self'.packages.ROPgadget
    ];
  };
}
