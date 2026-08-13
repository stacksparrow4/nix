{ moduleWithSystem, ... }:

{
  flake.homeModules.general =
    { pkgs, ... }:
    {
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
        nix-search-cli
        sqlite
        whois
        curl # technically already exists in system package, but putting it here allows it to show inside docker which only uses home manager
        gnupg
        awscli
        (writeShellApplication {
          name = "ssh";
          text = ''
            export TERM=xterm-256color

            ${openssh}/bin/ssh -o WarnWeakCrypto=no "$@"
          '';
        })
        deploy-rs
        age
        ssh-to-age
        sops
      ];
    };

  flake.homeModules.general-linux = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = with self'.packages; [
        nodemon
        dumbpipe
      ];

      nix.extraOptions = ''
        !include /home/sprrw/.local/nix-access-tokens.conf
      '';
    }
  );
}
