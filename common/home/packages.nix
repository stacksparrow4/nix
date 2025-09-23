{ pkgs, lib, config, inputs, ... }:

let cfg = config.sprrw.packages; in {
  options = {
    sprrw.packages = {
      installGuiPackages = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      installLinuxPackages = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = {
    home.packages = with pkgs; [
      # General packages, for Mac and Linux
      bat
      ydiff

      file
      xxd
      killall
      dig
      socat

      yazi
      
      unzip
      zip
      p7zip

      xsel
      xclip

      gnumake
      gcc
      uv
      (python3.withPackages (pypkgs: with pypkgs; [ requests ]))
      python313Packages.ipython
      openssl

      jq
      jless
      yq-go

      wget
      tealdeer

      fzf
      fd
      ripgrep

      sshpass

      semgrep

      (pkgs.writeShellScriptBin "vimgolf" ''
        export PATH="${pkgs.vim}/bin:$PATH"

        ${pkgs.vimgolf}/bin/vimgolf "$@"
      '')

      nix-search-cli

      sqlite

      whois
    ] ++ (if cfg.installGuiPackages then [
      # Gui packages for linux
      discord
      gimp
      inkscape
      spotify
      brave
      krita
      libreoffice
      obs-studio
      blender
      binaryninja-free
      ghidra
      obsidian
      rofi
      flameshot
      freerdp
      bruno
      wireshark
    ] else []) ++ (if cfg.installLinuxPackages then [
      # Linux only CLI tools
      ltrace
      linux-manual
      man-pages
      man-pages-posix
      netcat-openbsd
      lsof

      (pkgs.writeShellScriptBin "proxychains" ''
        ${pkgs.proxychains}/bin/proxychains4 -q "$@"
      '')
    ] else []);
  };
}
