{
  flake.homeModules.programming-rust =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cargo
        rustc
        crate2nix
      ];
    };
}
