{ lib, ... }:

{
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  users.users.sprrw = {
    isNormalUser = true;
    description = "sprrw";
    extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
    ];
  };
}
