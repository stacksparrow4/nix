{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.sec-gui = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.binaryninja-free
        pkgs.ghidra
        pkgs.wireshark
        self'.packages.caido
      ];
    }
  );
}
