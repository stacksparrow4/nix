{ moduleWithSystem, ... }:

{
  flake.homeModules.gui-signal = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.signal-desktop-entry ];
    }
  );
}
