{ lib, pkgs, ... }:

let
  isoModule =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

      isoImage.squashfsCompression = null;

      boot.kernelParams = [ "console=ttyS0" ];

      system.build.sandboxDirectBoot = pkgs.runCommandLocal "vm-direct-boot" { } ''
        mkdir -p "$out"
        ln -s ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} "$out/kernel"
        ln -s ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} "$out/initrd"
        ln -s ${config.system.build.image}/${config.image.filePath} "$out/image.iso"
        printf '%s' ${lib.escapeShellArg "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"} > "$out/cmdline"
      '';
    };
in
{
  imports = [ ../../../common/system ];

  image.modules.iso = isoModule;

  sprrw.headless = true;

  boot.loader.timeout = lib.mkForce 0;

  boot.initrd.systemd.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 22 ];

    startWhenNeeded = true;

    generateHostKeys = false;
    hostKeys = [
      {
        type = "ed25519";
        path = "/etc/ssh/ssh_host_ed25519_key";
      }
    ];

    settings = {
      UseDns = false;

      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";

      AllowUsers = null;
      X11Forwarding = false;
    };
  };

  systemd.services.sandbox-credentials = {
    description = "Install per-sandbox SSH credentials";

    # Not before=sshd.socket: services are implicitly After=basic.target, itself
    # After=sockets.target, so that cycles and systemd drops the sshd.socket job.
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "sysinit.target" ];
    before = [
      "sysinit.target"
      "shutdown.target"
    ];
    conflicts = [ "shutdown.target" ];

    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      creds=/run/credentials/@system

      install -d -m 0755 /etc/ssh
      if [ -s "$creds/sandbox.host_key" ]; then
        install -m 0600 "$creds/sandbox.host_key" /etc/ssh/ssh_host_ed25519_key
      elif ! [ -s /etc/ssh/ssh_host_ed25519_key ]; then
        ssh-keygen -q -t ed25519 -N "" -C "" -f /etc/ssh/ssh_host_ed25519_key
      fi

      install -d -m 0755 /etc/ssh/authorized_keys.d
      if [ -s "$creds/sandbox.authorized_keys" ]; then
        install -m 0644 "$creds/sandbox.authorized_keys" /etc/ssh/authorized_keys.d/sprrw
      fi
    '';
  };

  home-manager.users.sprrw = ../home;

  users.users.sprrw = {
    isNormalUser = true;
    description = "sprrw";
    extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
    ];
    initialPassword = "password";
  };

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  networking.hostName = "vm";

  networking.networkmanager.enable = false;
  networking.useDHCP = false;
  networking.useNetworkd = true;

  systemd.network = {
    wait-online.enable = false;
    networks."10-slirp" = {
      matchConfig.Type = "ether";
      address = [ "10.0.2.15/24" ];
      routes = [ { Gateway = "10.0.2.2"; } ];
      linkConfig.RequiredForOnline = false;
    };
  };

  services.resolved.enable = false;
  networking.resolvconf.enable = false;
  environment.etc."resolv.conf".text = ''
    nameserver 10.0.2.3
    options edns0
  '';

  networking.firewall.enable = false;

  systemd.oomd.enable = false;
  services.timesyncd.enable = false;
  services.logrotate.enable = false;
  systemd.services.systemd-pstore.enable = false;
  documentation.nixos.enable = false;

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

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.11";
}
