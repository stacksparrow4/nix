{
  flake.homeModules.linux-rofi =
    { pkgs, ... }:
    {
      home.file.".config/rofi/config.rasi".text = ''
        @theme "${pkgs.rofi}/share/rofi/themes/Arc-Dark.rasi"
      '';

      home.packages = [ pkgs.rofi ];
    };
}
