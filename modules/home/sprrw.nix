{ moduleWithSystem, ... }:

{
  flake.homeModules.sprrw-cli = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      # TODO: Generate bash autocompletes
      home.packages = [ self'.packages.sprrw ];
    }
  );
}
