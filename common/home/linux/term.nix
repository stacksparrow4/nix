{ pkgs, lib, config, ... }:

{
  options.sprrw.linux.term.enable = lib.mkEnableOption "term";

  config = lib.mkIf config.sprrw.linux.term.enable {
    home.packages = with pkgs; [
      ltrace
      linux-manual
      man-pages
      man-pages-posix
      netcat-openbsd
      lsof
      neofetch

      (pkgs.writeShellScriptBin "proxychains" ''
        ${pkgs.proxychains}/bin/proxychains4 -q "$@"
      '')
    ];
  };
}
