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
      nix-search-cli
      sqlite
      whois
      curl # technically already exists in system package, but putting it here allows it to show inside docker which only uses home manager
      gnupg
    ];
  };
}
