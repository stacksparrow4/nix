{
  flake.homeModules.databases =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        postgresql
        mariadb
      ];
    };
}
