{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.reversing.enable = lib.mkEnableOption "reversing";
  };

  config = lib.mkIf config.sprrw.sec.reversing.enable {
    home.packages = with pkgs; [
      binaryninja-free
      ghidra
      radare2
    ];
  };
}
