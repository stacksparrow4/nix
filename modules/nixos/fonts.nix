{
  flake.nixosModules.fonts =
    { pkgs, ... }:
    let
      fonts = with pkgs; [
        nerd-fonts.iosevka-term
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ];
    in
    {
      fonts.packages = fonts;

      # Bind mounted to /usr/share/fonts for flatpak to use
      system.fsPackages = [ pkgs.bindfs ];
      fileSystems."/usr/share/fonts" = {
        device =
          pkgs.buildEnv {
            name = "system-fonts";
            paths = fonts;
            pathsToLink = [ "/share/fonts" ];
          }
          + "/share/fonts";
        fsType = "fuse.bindfs";
        options = [
          "ro"
          "resolve-symlinks"
          "x-gvfs-hide"
        ];
      };
    };
}
