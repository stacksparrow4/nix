{ moduleWithSystem, ... }:

{
  flake.homeModules.linux-tools = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        ltrace
        man-pages
        man-pages-posix
        netcat-openbsd
        lsof
        traceroute
        bubblewrap
      ] ++ [
        self'.packages.proxychains
      ];
    }
  );
}
