{
  pkgs,
  lib,
  config,
  self',
  ...
}:

{
  options.sprrw.linux.term.enable = lib.mkEnableOption "term";

  config = lib.mkIf config.sprrw.linux.term.enable {
    home.packages = [
      pkgs.ltrace
      pkgs.linux-manual
      pkgs.man-pages
      pkgs.man-pages-posix
      pkgs.netcat-openbsd
      pkgs.lsof
      pkgs.traceroute
      pkgs.bubblewrap

      self'.packages.neofetch
      self'.packages.proxychains
    ];
  };
}
