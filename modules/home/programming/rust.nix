{
  flake.modules.homeManager.rust =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cargo
        rustc
        crate2nix
      ];
    };
}
