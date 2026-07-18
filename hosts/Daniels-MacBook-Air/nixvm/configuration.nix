{ pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  environment.systemPackages = with pkgs; [
    neovim
    (pkgs.runCommand "vim-aliases" {} ''
      mkdir -p $out/bin
      ln -s ${neovim}/bin/nvim $out/bin/vi
      ln -s ${neovim}/bin/nvim $out/bin/vim
    '')
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "macbook-vm";

  networking.networkmanager.enable = true;

  users.users.sprrw = {
    isNormalUser = true;
    description = "sprrw";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  nix.settings.trusted-users = [ "root" "@wheel" ];

  services.openssh.enable = true;

  networking.firewall.enable = false;

  security.sudo.wheelNeedsPassword = false;

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  system.stateVersion = "25.11"; # Did you read the comment?

}
