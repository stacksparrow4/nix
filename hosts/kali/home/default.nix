{ pkgs, ... }:

{
  imports = [
     ../../../common/home
  ];

  home = {
    username = "kali";
    homeDirectory = "/home/kali";
  };

  # Uncomment for faster build
  # sprrw.useAllEnvironments = false;
  
  sprrw.rofi.enable = false;
  sprrw.alacritty.enable = false;

  home.file.".config/alacritty/alacritty.toml".text = ''
    [env]
    TERM = "xterm-256color"

    [font]
    size = 13

    [font.normal]
    family = "Iosevka Term Nerd Font Mono"

    [terminal.shell]
    program = "${pkgs.tmux}/bin/tmux"

    [window]
    option_as_alt = "Both"
    startup_mode = "Maximized"
  '';

  home.file.".config/nix/nix.conf".text = ''
    extra-experimental-features = flakes nix-command
  '';

  programs.bash.bashrcExtra = ''
    alias xfreerdp='xfreerdp3'

    alias sudo='sudo -E'
  '';

  sprrw.packages = {
    installGuiPackages = false;
  };

  home.packages = [
    (pkgs.writeShellScriptBin "update-res" ''
      xrandr --output Virtual-1 --mode $(xrandr -q | grep -oE '^ *[0-9]+x[0-9]+' | awk '{print $1}' | head -n 1)
    '')
  ];
}
