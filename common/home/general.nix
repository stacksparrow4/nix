{
  pkgs,
  lib,
  config,
  self',
  ...
}:

{
  options.sprrw.general.enable = lib.mkOption { default = true; };

  config = lib.mkIf config.sprrw.general.enable {
    home.packages = [
      pkgs.bat
      pkgs.ydiff
      pkgs.file
      pkgs.xxd
      pkgs.killall
      pkgs.dig
      pkgs.socat
      pkgs.unzip
      pkgs.zip
      pkgs.p7zip
      pkgs.uv
      (pkgs.python3.withPackages (pypkgs: with pypkgs; [ requests ]))
      pkgs.openssl
      pkgs.jq
      pkgs.jless
      pkgs.yq-go
      pkgs.wget
      pkgs.tealdeer
      pkgs.fzf
      pkgs.fd
      pkgs.ripgrep
      pkgs.sshpass
      self'.packages.sshp
      pkgs.nix-search-cli
      pkgs.sqlite
      pkgs.whois
      pkgs.curl # technically already exists in system package, but putting it here allows it to show inside docker which only uses home manager
      pkgs.gnupg
      pkgs.awscli
      # Changes the behaviour of ssh itself, so it stays here rather than
      # becoming a package.
      (pkgs.writeShellApplication {
        name = "ssh";
        text = ''
          export TERM=xterm-256color

          ${pkgs.openssh}/bin/ssh -o WarnWeakCrypto=no "$@"
        '';
      })
    ]
    # The sandbox helper is Linux-only.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      self'.packages.nodemon
      self'.packages.dumbpipe
    ];
  };
}
