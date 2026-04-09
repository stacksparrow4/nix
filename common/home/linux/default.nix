{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./sway.nix
    ./rofi.nix
    ./term.nix
    ./yubikey.nix
  ];

  options = {
    sprrw.linux.enable = lib.mkEnableOption "linux";
  };

  config = lib.mkIf config.sprrw.linux.enable {
    home.packages = with pkgs; [
      dragon-drop
    ];

    # services.opensnitch-ui = {
    #   enable = true;
    # };
    # systemd.user.services.opensnitch-ui.Service.Environment = [ "DISPLAY=:0" ];

    sprrw.linux = {
      rofi.enable = true;
      sway.enable = true;
      term.enable = true;
      yubikey.enable = true;
    };

    # 1password stuff
    services.gnome-keyring = {
      enable = true;
      components = [ "secrets" ];
    };

    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
    };
  };
}
