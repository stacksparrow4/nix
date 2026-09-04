{ moduleWithSystem, ... }:

{
  flake.homeModules.general = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
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
          age
          ssh-to-age
        ]
        ++ (with self'.packages; [ python ]);
    }
  );

  flake.homeModules.general-linux = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = with self'.packages; [
        nodemon
        tailcat
      ];

      nix.extraOptions = ''
        !include /home/sprrw/.local/nix-access-tokens.conf
      '';
    }
  );
}
