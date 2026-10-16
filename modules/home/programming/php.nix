{
  flake.homeModules.php =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        php
      ];
    };
}
