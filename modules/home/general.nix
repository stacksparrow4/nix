{ moduleWithSystem, ... }:

{
  # Portable CLI baseline. Everything here works on both Linux and darwin.
  flake.homeModules.general = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
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
      ];
    }
  );

  # The Linux-only remainder of `general`: these two wrappers are sandboxed, and
  # the sandbox helper is bubblewrap-based. The nix access token include also
  # lives here, since the path it names only exists on the Linux hosts.
  flake.homeModules.general-linux = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [
        self'.packages.nodemon
        self'.packages.dumbpipe
      ];

      nix.extraOptions = ''
        !include /home/sprrw/.local/nix-access-tokens.conf
      '';
    }
  );
}
