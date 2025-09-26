{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.kubernetes.enable = lib.mkEnableOption "kubernetes";
  };

  config = lib.mkIf config.sprrw.programming.kubernetes.enable {
    home.packages = with pkgs; [
      kubectl
      kubernetes-helm
    ];
  };
}
