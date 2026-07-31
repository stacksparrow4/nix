{ config, lib, ... }:

{
  # services.zerotierone = {
  #   enable = true;
  #   joinNetworks = [ "83048a0632b9c48e" ];
  # };

  imports = [
    ./hardware-configuration.nix
    ../../../common/system
    ./gaming.nix
  ];

  boot.loader.timeout = lib.mkForce 9999;

  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];

  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  home-manager.users.sprrw = ../home;

  users.users.sprrw.extraGroups = [ "audio" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nest01";
  networking.extraHosts = ''
    192.9.173.108 kubernetes.default
  '';

  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.opentabletdriver.enable = true;
  hardware.opentabletdriver.daemon.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
