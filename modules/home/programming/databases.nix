{
  flake.homeModules.programming-databases =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        postgresql
        mariadb
      ];
    };
}
