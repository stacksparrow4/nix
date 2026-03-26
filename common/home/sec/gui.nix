{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.sec.gui.enable = lib.mkEnableOption "gui";
  };

  config = lib.mkIf config.sprrw.sec.gui.enable {
    home.packages = with pkgs; [
      binaryninja-free
      ghidra
      wireshark
    ];
  };
}
