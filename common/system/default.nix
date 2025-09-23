{
  imports = [
    ./audio.nix
    ./display.nix
    ./fonts.nix
    ./nix-config.nix
    ./virt.nix
  ];

  programs._1password.enable = true;
  programs._1password-gui.enable = true;

  programs.wireshark.enable = true;
}
