{ moduleWithSystem, ... }:

{
  # GUI security tools. caido used to be its own aspect but was always enabled
  # together with the rest of these, so it is merged in here.
  flake.homeModules.sec-gui = moduleWithSystem (
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
