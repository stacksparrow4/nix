{
  pkgs,
  lib,
  config,
  mkSandbox,
  ...
}:

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
      traceroute
      bubblewrap

      (mkSandbox {
        name = "neofetch";
        prog = "${fastfetch}/bin/fastfetch";
      })
      (pkgs.writeShellScriptBin "proxychains" ''
        ${pkgs.proxychains-ng}/bin/proxychains4 -q "$@"
      '')
    ];
  };
}
