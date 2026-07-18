{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [
    ../../../common/home
  ];

  home = {
    username = "dan";
    homeDirectory = "/Users/dan";
  };

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      env = "TERMINFO_DIRS=/Users/dan/.terminfo";
      command = lib.mkForce "${pkgs.tmux}/bin/tmux";
      app-notifications = "no-clipboard-copy";
      macos-option-as-alt = true;
    };
  };

  home.file.".terminfo" = {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Ghostty.app/Contents/Resources/terminfo";
  };

  home.packages = with pkgs; [
    sshpass
    shtris
    (pkgs.writeShellApplication {
      name = "connect";
      text = ''
        sshpass -p password ssh root@192.168.64.2
      '';
    })
    (pkgs.writeShellApplication {
      name = "nixvm-rebuild";
      text = ''
        nix run nixpkgs#nixos-rebuild -- switch \
          --flake ~/nixos/hosts/Daniels-MacBook-Air/nixvm#macbook-vm \
          --target-host root@192.168.64.2 \
          --build-host root@192.168.64.2
      '';
    })
  ];

  home.file.".config/nix/nix.conf".text = ''
    experimental-features = nix-command flakes
    builders = ssh://root@192.168.64.2 aarch64-linux
  '';

  # Note: this ssh host has to be valid for the Mac root user
  # sudo launchctl kickstart -k system/org.nixos.nix-daemon

  home.sessionVariables = {
    NIX_PATH = "nixpkgs=${inputs.nixpkgs}:nixpkgs-unstable=${inputs.nixpkgs-unstable}";
  };

  sprrw = {
    nvim = {
      enable = true;
      sandboxed = false;
    };
    term = {
      zshrc.enable = true;
      yazi.enable = true;
      tmux = {
        enable = true;
        defaultTerm = "ghostty";
      };
      ghostty = {
        font = {
          family = "IosevkaTerm Nerd Font Mono";
          size = 14;
        };

        installTerminfo = false;
      };
    };
    programming.git.enable = true;
  };
}
