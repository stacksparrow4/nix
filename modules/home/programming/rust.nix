{
  flake.homeModules.programming-rust =
    { pkgs, ... }:
    {
      home.sessionPath = [ "$HOME/.cargo/bin" ];

      home.packages = with pkgs; [
        cargo
        rustc
        rustfmt
        crate2nix
      ];
    };
}
