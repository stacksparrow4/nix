{ pkgs, lib, config, ... }:

{
  options.sprrw.term.linux.enable = lib.mkEnableOption "linux";

  config = lib.mkIf config.sprrw.term.linux.enable {
    home.packages = with pkgs; [
      ltrace
      linux-manual
      man-pages
      man-pages-posix
      netcat-openbsd
      lsof

      (pkgs.writeShellScriptBin "proxychains" ''
        ${pkgs.proxychains}/bin/proxychains4 -q "$@"
      '')
    ];
  };
}
