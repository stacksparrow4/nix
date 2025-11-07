{
  imports = [
    ./linux
    ./nvim
    ./programming
    ./sec
    ./scripts
    ./term
    ./gui.nix
    ./sandboxing.nix
  ];

  home.file.".config/nixpkgs/config.nix".text = ''
    { allowUnfree = true; }
  '';

  home.stateVersion = "24.11"; # Please read the comment before changing.

  programs.home-manager.enable = true;
}
