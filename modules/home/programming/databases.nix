{
  flake.modules.homeManager.databases =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        postgresql
        mariadb
      ];
    };
}
