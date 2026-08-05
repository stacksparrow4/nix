{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-cracking = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.hashcat
        pkgs.john
        self'.packages.hydra
      ];
    }
  );
}
