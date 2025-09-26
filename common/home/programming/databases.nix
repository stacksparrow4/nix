{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.databases.enable = lib.mkEnableOption "databases";
  };

  config = lib.mkIf config.sprrw.programming.databases.enable {
    home.packages = with pkgs; [
      postgresql
      mysql-client
    ];
  };
}
