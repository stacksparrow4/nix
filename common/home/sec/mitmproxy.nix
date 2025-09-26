{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.mitmproxy.enable = lib.mkEnableOption "mitmproxy";
  };

  config = lib.mkIf config.sprrw.sec.mitmproxy.enable {
    home.packages = with pkgs; [
      mitmproxy
    ];
  };
}
