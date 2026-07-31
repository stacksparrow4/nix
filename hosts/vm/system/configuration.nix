{ lib, ... }:

{
  imports = [ ../../../common/system ];

  image.modules.iso.isoImage.squashfsCompression = null;

  sprrw.headless = true;
  boot.loader.timeout = lib.mkForce 1;

  networking.firewall.allowedTCPPorts = [ 22 ];
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = true;
      AllowUsers = null; # Allows all users by default. Can be [ "user1" "user2" ]
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
  };

  home-manager.users.sprrw = ../home;

  users.users.sprrw.initialPassword = "password";

  nix.settings.trusted-users = [ "root" "@wheel" ];

  networking.hostName = "vm";

  system.stateVersion = "24.11";
}
