{
  imports = [
    ./docker.nix
    ./linux
    ./nvim
    ./programming
    ./sec
    ./scripts
    ./term
    ./gui
    ./sandboxing.nix
  ];

  home.file.".config/nixpkgs/config.nix".text = ''
    { allowUnfree = true; }
  '';

  home.stateVersion = "24.11"; # Please read the comment before changing.

  programs.home-manager.enable = true;
}
