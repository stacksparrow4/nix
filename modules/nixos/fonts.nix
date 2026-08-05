{
  flake.nixosModules.fonts =
    { pkgs, ... }:
    {
      fonts.packages = [
        pkgs.nerd-fonts.iosevka-term
        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-cjk-serif
      ];
    };
}
