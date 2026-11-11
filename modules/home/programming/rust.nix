{
  flake.modules.homeManager.rust =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cargo
        crate2nix
      ];
    };
}
