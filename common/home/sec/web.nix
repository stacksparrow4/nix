{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.web.enable = lib.mkEnableOption "web";
  };

  config = lib.mkIf config.sprrw.sec.web.enable {
    home.packages = (with self'.packages; [
      mitmproxy
      interactsh-boxed
      oob-boxed
    ]);
  };
}
