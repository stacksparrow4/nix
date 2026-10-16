{ moduleWithSystem, ... }:

{
  flake.homeModules.linux-tools = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.ltrace
        pkgs.linux-manual
        pkgs.man-pages
        pkgs.man-pages-posix
        pkgs.netcat-openbsd
        pkgs.lsof
        pkgs.traceroute
        pkgs.bubblewrap

        self'.packages.proxychains
      ];
    }
  );
}
