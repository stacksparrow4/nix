{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.dotnet.enable = lib.mkEnableOption "dotnet";
  };

  config = lib.mkIf config.sprrw.programming.dotnet.enable {
    home.packages = with pkgs; [
      dotnet-sdk
    ];
  };
}
