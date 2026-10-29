{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.cracking = moduleWithSystem (
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
