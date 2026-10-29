{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.forensics = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        self'.packages.exiftool
        self'.packages.binwalk
        self'.packages.ent
        pkgs.tcpdump
      ];
    }
  );
}
