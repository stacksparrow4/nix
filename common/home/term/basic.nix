{ pkgs, lib, config, ... }:

{
  options.sprrw.term.basic.enable = lib.mkEnableOption "basic";

  config = lib.mkIf config.sprrw.term.basic.enable {
    home.packages = with pkgs; [
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
      # TODO: put this in a "large" packages section
      ffmpeg
    ];
  };
}
