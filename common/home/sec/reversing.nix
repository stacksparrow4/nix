{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.reversing.enable = lib.mkEnableOption "reversing";
  };

  config = lib.mkIf config.sprrw.sec.reversing.enable {
    home.packages = [
      (pkgs.rizin.withPlugins (plugins: with plugins; [ rz-ghidra ]))
      self'.packages.webcrack-boxed
    ];
  };
}
