{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.general = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          ydiff
          file
          xxd
          killall
          dig
          socat
          unzip
          zip
          p7zip
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
          age
          ssh-to-age
          fastfetch
          nix-tree
          ltrace
          man-pages
          man-pages-posix
          netcat-openbsd
          lsof
          traceroute
          bubblewrap
        ]
        ++ (with self'.packages; [
          ssh
          proxychains
        ]);

      sprrw.term.shellExtra = ''
        alias yd='ydiff'
        alias yds='ydiff --staged'
      '';
    }
  );
}
