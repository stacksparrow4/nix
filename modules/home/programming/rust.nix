{
  flake.homeModules.rust =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cargo
        rustc
        crate2nix
      ];
    };
}
