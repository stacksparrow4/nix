{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.general.enable = lib.mkOption { default = true; };

  config = lib.mkIf config.sprrw.general.enable {
    home.packages = with pkgs; [
      bat
      ydiff
      file
      xxd
      killall
      dig
      socat
      unzip
      zip
      p7zip
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
      curl # technically already exists in system package, but putting it here allows it to show inside docker which only uses home manager
      gnupg
      (config.sprrw.sandbox.create {
        name = "shtris";
        stdin = true;
        tty = true;
        prog = "${shtris}/bin/shtris";
      })
      gh
      (config.sprrw.sandbox.create {
        name = "zbarimg";
        stdin = true;
        prog = "${zbar}/bin/zbarimg";
      })
      (config.sprrw.sandbox.create {
        name = "twitch-dl";
        shareCwd = true;
        prog = "${twitch-dl}/bin/twitch-dl";
      })
      ffmpeg
    ];
  };
}
