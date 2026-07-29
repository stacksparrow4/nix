# Configuration for the throwaway sandbox VM booted by `sandbox --vm`.
#
# This image is shared read-only between all concurrently running sandboxes, so
# it must not contain anything that identifies or authenticates a *specific*
# VM. Per-VM SSH credentials are injected at boot time by the `sandbox` tool as
# systemd credentials over SMBIOS type 11 OEM strings, and installed by
# `sandbox-credentials.service` below.

{ lib, pkgs, ... }:

let
  # Modules that only apply to the ISO image variant (`system.build.images.iso`).
  isoModule =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      # Pulls virtio_blk/virtio_pci/virtio_net into stage 1. The sandbox tool
      # attaches the image as a virtio-blk disk rather than an emulated ATAPI
      # cdrom, which is dramatically faster.
      imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

      # Trade image size for boot speed: no squashfs decompression.
      isoImage.squashfsCompression = null;

      # The sandbox tool runs QEMU with `-serial file:.../console.log`, so send
      # the boot log there to make failures debuggable without a display.
      boot.kernelParams = [ "console=ttyS0" ];

      # Everything the sandbox tool needs to boot this image with
      # -kernel/-initrd/-append, bypassing SeaBIOS and isolinux entirely. Loading
      # a ~50MB initrd through 16-bit BIOS INT 13h off an emulated ATAPI CD was
      # the single largest chunk of the old startup time.
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

  # Irrelevant when direct-booting, but avoids a 1s stall if the ISO is ever
  # booted through its own bootloader.
  boot.loader.timeout = lib.mkForce 0;

  # Parallelises stage 1 device waits instead of the scripted stage 1's polling
  # loop. If the VM ever fails to find its root device, this is the first thing
  # to revert.
  boot.initrd.systemd.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 22 ];

    # Socket activation: the listener exists from sockets.target, very early in
    # boot, so connection attempts queue instead of being refused. Removes the
    # startup race entirely and gets us connectable much sooner than
    # multi-user.target.
    startWhenNeeded = true;

    # Never generate host keys in the guest. The upstream default is RSA-4096,
    # which is regenerated on *every* boot here (the live ISO has a fresh tmpfs
    # /etc) and blocks sshd for seconds. The host generates an ed25519 key per
    # VM in ~5ms and passes it in as a credential.
    generateHostKeys = false;
    hostKeys = [
      {
        type = "ed25519";
        path = "/etc/ssh/ssh_host_ed25519_key";
      }
    ];

    settings = {
      # Was `true`, which is not the upstream default. Under slirp the client
      # appears as 10.0.2.2, whose PTR lookup never resolves, so sshd stalled on
      # resolver timeouts before even reaching auth.
      UseDns = false;

      # Every VM used to share the password "password", and slirp lets a guest
      # reach host loopback via 10.0.2.2 -- so any sandbox could log into any
      # other sandbox. Per-VM pubkeys only.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";

      AllowUsers = null;
      X11Forwarding = false;
    };
  };

  # Installs the per-VM credentials handed to us over SMBIOS. systemd's PID 1
  # picks up `io.systemd.credential.binary:` OEM strings and drops them in
  # /run/credentials/@system.
  systemd.services.sandbox-credentials = {
    description = "Install per-sandbox SSH credentials";

    # Runs during sysinit, which is ordered before sockets.target and therefore
    # before sshd.socket starts listening.
    #
    # Do NOT write `before = [ "sshd.socket" ]` here. A normal service gets an
    # implicit After=basic.target, basic.target is After=sockets.target, and a
    # socket unit gets an implicit Before=sockets.target -- so ordering a service
    # before a socket closes a cycle:
    #
    #   sshd.socket -> sockets.target -> basic.target -> this -> sshd.socket
    #
    # systemd breaks such cycles by deleting a job, and it picks sshd.socket.
    # Nothing then listens on port 22, slirp's forwarded SYN goes unanswered and
    # the VM looks like it hangs forever.
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
        # Fallback for booting the image by hand. ed25519 keygen is instant.
        ssh-keygen -q -t ed25519 -N "" -C "" -f /etc/ssh/ssh_host_ed25519_key
      fi

      # /etc/ssh/authorized_keys.d/%u is always in authorizedKeysFiles, so this
      # avoids racing home-manager over ~/.ssh.
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
    # Only usable on the serial/tty console; SSH password auth is off.
    initialPassword = "password";
  };

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  networking.hostName = "vm";

  # Each QEMU process has its own in-process slirp stack with its own DHCP
  # client table, so every VM is handed 10.0.2.15 anyway -- configuring it
  # statically just skips NetworkManager (plus the wpa_supplicant it drags in)
  # and the DHCP client's duplicate-address-detection delay. Matching on
  # Type=ether keeps this independent of NIC naming.
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

  # useNetworkd defaults resolved on. slirp's DNS proxy is always 10.0.2.3, so a
  # static file removes both the resolved daemon and resolvconf.service from
  # boot.
  services.resolved.enable = false;
  networking.resolvconf.enable = false;
  environment.etc."resolv.conf".text = ''
    nameserver 10.0.2.3
    options edns0
  '';

  # Nothing can reach this VM except the per-VM unix socket QEMU forwards to
  # port 22, so iptables-restore on every boot buys nothing.
  networking.firewall.enable = false;

  # Boot-time fat that a seconds-lived sandbox has no use for.
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
