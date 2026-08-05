{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.mobile.enable = lib.mkEnableOption "mobile";
  };

  config = lib.mkIf config.sprrw.sec.mobile.enable {
    home.packages = [
      pkgs.frida-tools
      self'.packages.apktool
      self'.packages.jadx
      pkgs.android-tools
      self'.packages.ipsw
    ];
  };
}
