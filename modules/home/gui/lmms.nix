{ moduleWithSystem, ... }:

{
  flake.homeModules.gui-lmms = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.lmms-desktop-entry ];
    }
  );
}
