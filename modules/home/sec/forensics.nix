{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-forensics = moduleWithSystem (
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
