# home-manager's flake-parts module declares `flake.homeModules` (typed
# lazyAttrsOf deferredModule, tagged _class = "homeManager") and
# `flake.homeConfigurations`. The NixOS equivalent, `flake.nixosModules`, is
# built into flake-parts. Both merge per-name and lazily, which is what lets
# many aspect files contribute to one namespace.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.flakeModules.home-manager ];
}
