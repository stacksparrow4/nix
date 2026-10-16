{ moduleWithSystem, ... }:

{
  flake.homeModules.cracking = moduleWithSystem (
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
