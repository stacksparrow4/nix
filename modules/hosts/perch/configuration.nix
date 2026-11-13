{ inputs, ... }:

{
  flake.nixosConfigurations.perch = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      (
        {
          lib,
          pkgs,
          ...
        }:

        {
          imports = [
            ./_hardware-configuration.nix
            inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
          ];

          hardware.asahi = {
            enable = true;
            pkgs = lib.mkForce import inputs.nixos-apple-silicon.inputs.nixpkgs {
              system = "aarch64-linux";
              overlays = [ inputs.nixos-apple-silicon.overlays.default ];
            };
            peripheralFirmwareDirectory = null;
          };

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = false;

          networking.hostName = "perch";

          networking.networkmanager = {
            enable = true;
            wifi.backend = "iwd";
          };

          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            extra-substituters = [ "https://nix-community.cachix.org" ];
            extra-trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
          };

          # Set your time zone.
          # time.timeZone = "Europe/Amsterdam";

          # Configure network proxy if necessary
          # networking.proxy.default = "http://user:password@proxy:port/";
          # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

          # Select internationalisation properties.
          # i18n.defaultLocale = "en_US.UTF-8";
          # console = {
          #   font = "Lat2-Terminus16";
          #   keyMap = "us";
          #   useXkbConfig = true; # use xkb.options in tty.
          # };

          # Enable the X11 windowing system.
          # services.xserver.enable = true;

          # Configure keymap in X11
          # services.xserver.xkb.layout = "us";
          # services.xserver.xkb.options = "eurosign:e,caps:escape";

          # Enable CUPS to print documents.
          # services.printing.enable = true;

          # Enable sound.
          # services.pulseaudio.enable = true;
          # OR
          # services.pipewire = {
          #   enable = true;
          #   pulse.enable = true;
          # };

          # Enable touchpad support (enabled default in most desktopManager).
          # services.libinput.enable = true;

          # Define a user account. Don't forget to set a password with ‘passwd’.
          users.users.sprrw = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            packages = with pkgs; [
              git
              neovim
            ];
          };

          security.sudo.wheelNeedsPassword = false;

          # programs.firefox.enable = true;

          # List packages installed in system profile.
          # You can use https://search.nixos.org/ to find more packages (and options).
          # environment.systemPackages = with pkgs; [
          #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
          #   wget
          # ];

          # Some programs need SUID wrappers, can be configured further or are
          # started in user sessions.
          # programs.mtr.enable = true;
          # programs.gnupg.agent = {
          #   enable = true;
          #   enableSSHSupport = true;
          # };

          # List services that you want to enable:

          # Enable the OpenSSH daemon.
          # services.openssh.enable = true;

          # Open ports in the firewall.
          # networking.firewall.allowedTCPPorts = [ ... ];
          # networking.firewall.allowedUDPPorts = [ ... ];
          # Or disable the firewall altogether.
          # networking.firewall.enable = false;

          # Copy the NixOS configuration file and link it from the resulting system
          # (/run/current-system/configuration.nix). This is useful in case you
          # accidentally delete configuration.nix.
          # system.copySystemConfiguration = true;

          # This option defines the first version of NixOS you have installed on this particular machine,
          # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
          #
          # Most users should NEVER change this value after the initial install, for any reason,
          # even if you've upgraded your system to a new NixOS release.
          #
          # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
          # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
          # to actually do that.
          #
          # This value being lower than the current NixOS release does NOT mean your system is
          # out of date, out of support, or vulnerable.
          #
          # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
          # and migrated your data accordingly.
          #
          # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
          system.stateVersion = "26.11"; # Did you read the comment?

        }
      )
    ];
  };
}
