{
  flake.homeModules.programming-rust =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cargo
        rustc
        rustfmt
        crate2nix
      ];
    };
}
