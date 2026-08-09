{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-reversing = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.rizin.withPlugins (plugins: with plugins; [ rz-ghidra ]))
        self'.packages.webcrack
        self'.packages.ilspycmd
      ];
    }
  );
}
