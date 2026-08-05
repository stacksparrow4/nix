{
  flake.homeModules.programming-php =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        php
      ];
    };
}
